use crate::{ffmpeg, recording::recorder::CameraConfig, rtsp};
use serde_json::json;
use sqlx::PgPool;
use std::{io, process::Stdio, time::Duration};
use tokio::{
    io::AsyncReadExt,
    process::{Child, Command},
    time::Instant,
};
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

const WIDTH: usize = 160;
const HEIGHT: usize = 90;
const FRAME_BYTES: usize = WIDTH * HEIGHT;
const PIXEL_DELTA_THRESHOLD: u8 = 20;
const QUIET_SECONDS: f64 = 2.0;

pub async fn supervise(camera: CameraConfig, database: PgPool, shutdown: CancellationToken) {
    if !camera.motion_enabled {
        return;
    }

    let mut attempt: u32 = 0;
    loop {
        if shutdown.is_cancelled() {
            break;
        }

        match run_once(&camera, &database, shutdown.child_token()).await {
            Ok(()) if shutdown.is_cancelled() => break,
            Ok(()) => {
                attempt = attempt.saturating_add(1);
                tracing::warn!(camera_id=%camera.id, "motion detector stream ended; restart scheduled");
            }
            Err(error) => {
                attempt = attempt.saturating_add(1);
                tracing::warn!(camera_id=%camera.id, %error, "motion detector failed; retry scheduled");
            }
        }

        let delay = rtsp::reconnect::delay(attempt);
        tokio::select! {
            () = tokio::time::sleep(delay) => {}
            () = shutdown.cancelled() => break,
        }
    }
}

async fn run_once(
    camera: &CameraConfig,
    database: &PgPool,
    shutdown: CancellationToken,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let mut child = start_ffmpeg(camera)?;
    ffmpeg::log_stderr(
        &mut child,
        &camera.id,
        "motion",
        camera.username.as_deref(),
        camera.password_secret.as_deref(),
    );

    let Some(mut stdout) = child.stdout.take() else {
        return Err("motion FFmpeg stdout unavailable".into());
    };

    tracing::info!(
        camera_id=%camera.id,
        fps=camera.motion_fps,
        sensitivity=camera.motion_sensitivity,
        stream=%camera.motion_stream,
        "motion detector started"
    );

    let trigger_threshold = sensitivity_threshold(camera.motion_sensitivity);
    let quiet_frames = ((camera.motion_fps * QUIET_SECONDS).ceil() as usize).max(2);
    let mut previous = vec![0_u8; FRAME_BYTES];
    let mut current = vec![0_u8; FRAME_BYTES];
    let mut have_previous = false;
    let mut quiet_count = 0usize;
    let mut active_event: Option<Uuid> = None;
    let started = Instant::now();

    loop {
        let read_result = tokio::select! {
            result = stdout.read_exact(&mut current) => Some(result),
            () = shutdown.cancelled() => None,
        };

        let Some(read_result) = read_result else {
            break;
        };
        match read_result {
            Ok(_) => {}
            Err(error) if error.kind() == io::ErrorKind::UnexpectedEof => break,
            Err(error) => return Err(error.into()),
        }

        if !have_previous {
            previous.copy_from_slice(&current);
            have_previous = true;
            continue;
        }

        let score = motion_score(&previous, &current);
        previous.copy_from_slice(&current);

        if score >= trigger_threshold {
            quiet_count = 0;
            match active_event {
                Some(event_id) => {
                    if let Err(error) = update_event_score(database, event_id, score).await {
                        tracing::warn!(camera_id=%camera.id, %error, "unable to update motion event score");
                    }
                }
                None => match start_event(database, camera, score).await {
                    Ok(event_id) => {
                        active_event = Some(event_id);
                        tracing::info!(
                            camera_id=%camera.id,
                            event_id=%event_id,
                            score,
                            threshold=trigger_threshold,
                            "motion event started"
                        );
                    }
                    Err(error) => {
                        tracing::warn!(camera_id=%camera.id, %error, "unable to persist motion event");
                    }
                },
            }
        } else if let Some(event_id) = active_event {
            quiet_count += 1;
            if quiet_count >= quiet_frames {
                if let Err(error) = end_event(database, event_id).await {
                    tracing::warn!(camera_id=%camera.id, %error, "unable to end motion event");
                } else {
                    tracing::info!(camera_id=%camera.id, event_id=%event_id, "motion event ended");
                    active_event = None;
                    quiet_count = 0;
                }
            }
        }
    }

    if let Some(event_id) = active_event {
        let _ = end_event(database, event_id).await;
    }

    ffmpeg::terminate(&mut child, &camera.id, "motion").await;
    if started.elapsed() >= Duration::from_secs(30) {
        tracing::debug!(camera_id=%camera.id, "motion detector completed a stable run");
    }
    Ok(())
}

fn start_ffmpeg(camera: &CameraConfig) -> Result<Child, io::Error> {
    let filter = format!(
        "fps={:.3},scale={WIDTH}:{HEIGHT}:flags=fast_bilinear,format=gray",
        camera.motion_fps
    );
    let mut command = Command::new("ffmpeg");
    command
        .args([
            "-hide_banner",
            "-loglevel",
            "warning",
            "-rtsp_transport",
            "tcp",
            "-timeout",
            "10000000",
            "-i",
        ])
        .arg(camera.motion_rtsp_url())
        .args([
            "-map",
            "0:v:0",
            "-an",
            "-vf",
            &filter,
            "-pix_fmt",
            "gray",
            "-f",
            "rawvideo",
            "pipe:1",
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .kill_on_drop(true);
    command.spawn()
}

fn sensitivity_threshold(sensitivity: f64) -> f64 {
    let sensitivity = sensitivity.clamp(0.0, 1.0);
    0.30 - (0.295 * sensitivity)
}

fn motion_score(previous: &[u8], current: &[u8]) -> f64 {
    if previous.len() != current.len() || previous.is_empty() {
        return 0.0;
    }

    let changed = previous
        .iter()
        .zip(current)
        .filter(|(before, after)| (**before).abs_diff(**after) >= PIXEL_DELTA_THRESHOLD)
        .count();
    changed as f64 / previous.len() as f64
}

async fn start_event(
    database: &PgPool,
    camera: &CameraConfig,
    score: f64,
) -> Result<Uuid, sqlx::Error> {
    let event_id = Uuid::new_v4();
    let metadata = json!({
        "detector": "frame-difference-v1",
        "stream": camera.motion_stream,
        "analysisFps": camera.motion_fps,
        "sensitivity": camera.motion_sensitivity,
        "width": WIDTH,
        "height": HEIGHT
    })
    .to_string();
    sqlx::query(
        "INSERT INTO events(id,camera_id,kind,started_at,score,metadata) VALUES($1,$2,'motion',now(),$3::double precision::numeric,$4::jsonb)",
    )
    .bind(event_id)
    .bind(&camera.id)
    .bind(score)
    .bind(metadata)
    .execute(database)
    .await?;
    Ok(event_id)
}

async fn update_event_score(
    database: &PgPool,
    event_id: Uuid,
    score: f64,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        "UPDATE events SET score=GREATEST(COALESCE(score,0),$2::double precision::numeric) WHERE id=$1",
    )
    .bind(event_id)
    .bind(score)
    .execute(database)
    .await?;
    Ok(())
}

async fn end_event(database: &PgPool, event_id: Uuid) -> Result<(), sqlx::Error> {
    sqlx::query("UPDATE events SET ended_at=COALESCE(ended_at,now()) WHERE id=$1")
        .bind(event_id)
        .execute(database)
        .await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn identical_frames_have_zero_motion() {
        let frame = vec![100_u8; FRAME_BYTES];
        assert_eq!(motion_score(&frame, &frame), 0.0);
    }

    #[test]
    fn changed_pixel_ratio_becomes_motion_score() {
        let previous = vec![0_u8; 100];
        let mut current = previous.clone();
        current[..25].fill(255);
        assert!((motion_score(&previous, &current) - 0.25).abs() < f64::EPSILON);
    }

    #[test]
    fn higher_sensitivity_reduces_trigger_threshold() {
        assert!(sensitivity_threshold(0.9) < sensitivity_threshold(0.2));
        assert!((sensitivity_threshold(1.0) - 0.005).abs() < 1e-9);
        assert!((sensitivity_threshold(0.0) - 0.30).abs() < 1e-9);
    }
}
