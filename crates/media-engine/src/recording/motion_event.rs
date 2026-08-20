use super::{paths::segment_path, prebuffer::PreEventBuffer, recorder::CameraConfig};
use chrono::{DateTime, Local};
use sqlx::PgPool;
use std::{
    path::{Path, PathBuf},
    process::Stdio,
};
use tokio::{
    fs,
    process::{Child, Command},
};
use uuid::Uuid;

pub struct MotionEventRecorder {
    camera: CameraConfig,
    storage: PathBuf,
    database: PgPool,
    event_id: Uuid,
    event_started_at: DateTime<Local>,
    work_dir: PathBuf,
    event_partial: PathBuf,
    pre_segments: Vec<(PathBuf, DateTime<Local>)>,
}

impl MotionEventRecorder {
    pub async fn start(
        camera: CameraConfig,
        storage: PathBuf,
        database: PgPool,
        event_id: Uuid,
        event_started_at: DateTime<Local>,
        prebuffer: Option<&PreEventBuffer>,
    ) -> Result<(Self, Child), String> {
        let work_dir = storage
            .join(".motion")
            .join(&camera.id)
            .join(event_id.to_string());
        if fs::try_exists(&work_dir).await.unwrap_or(false) {
            let _ = fs::remove_dir_all(&work_dir).await;
        }
        fs::create_dir_all(&work_dir)
            .await
            .map_err(|error| error.to_string())?;

        let pre_dir = work_dir.join("pre");
        let pre_segments = match prebuffer {
            Some(buffer) => buffer.snapshot(event_started_at, &pre_dir).await?,
            None => Vec::new(),
        };

        let event_partial = work_dir.join("event.mp4.partial");
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
            .arg(camera.rtsp_url())
            .args([
                "-map",
                "0:v:0",
                "-map",
                "0:a?",
                "-c:v",
                "copy",
                "-c:a",
                "aac",
                "-b:a",
                "64k",
                "-movflags",
                "+faststart",
                "-f",
                "mp4",
            ])
            .arg(&event_partial)
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .kill_on_drop(true);

        let child = command.spawn().map_err(|error| error.to_string())?;
        Ok((
            Self {
                camera,
                storage,
                database,
                event_id,
                event_started_at,
                work_dir,
                event_partial,
                pre_segments,
            },
            child,
        ))
    }

    pub fn pre_event_segment_count(&self) -> usize {
        self.pre_segments.len()
    }

    pub async fn finalize(self) -> Result<PathBuf, String> {
        let event_clip = self.work_dir.join("event.mp4");
        if fs::try_exists(&self.event_partial).await.unwrap_or(false) {
            fs::rename(&self.event_partial, &event_clip)
                .await
                .map_err(|error| error.to_string())?;
        }
        if !fs::try_exists(&event_clip).await.unwrap_or(false) {
            return Err("motion event recorder did not produce a file".to_string());
        }
        if probe_duration_ms(&event_clip).await.is_none() {
            return Err("motion event recorder did not produce a playable MP4".to_string());
        }

        let requested_start = self
            .pre_segments
            .first()
            .map(|(_, start)| *start)
            .unwrap_or(self.event_started_at);
        let requested_target = segment_path(&self.storage, &self.camera.id, requested_start)
            .map_err(|error| error.to_string())?;
        if let Some(parent) = requested_target.parent() {
            fs::create_dir_all(parent)
                .await
                .map_err(|error| error.to_string())?;
        }

        let mut inputs: Vec<PathBuf> = self
            .pre_segments
            .iter()
            .map(|(path, _)| path.clone())
            .collect();
        inputs.push(event_clip.clone());

        let (target, start, used_prebuffer) = if inputs.len() == 1 {
            move_event_clip(&event_clip, &requested_target).await?;
            (requested_target, self.event_started_at, false)
        } else {
            match concat_mp4s(&inputs, &requested_target, &self.work_dir).await {
                Ok(()) => (requested_target, requested_start, true),
                Err(error) => {
                    tracing::warn!(
                        camera_id=%self.camera.id,
                        event_id=%self.event_id,
                        %error,
                        "pre-event concat failed; preserving the event recording without prebuffer"
                    );
                    let fallback =
                        segment_path(&self.storage, &self.camera.id, self.event_started_at)
                            .map_err(|path_error| path_error.to_string())?;
                    if let Some(parent) = fallback.parent() {
                        fs::create_dir_all(parent)
                            .await
                            .map_err(|mkdir_error| mkdir_error.to_string())?;
                    }
                    move_event_clip(&event_clip, &fallback).await?;
                    (fallback, self.event_started_at, false)
                }
            }
        };

        let duration_ms = probe_duration_ms(&target)
            .await
            .ok_or_else(|| "final motion recording is not a playable MP4".to_string())?;
        let metadata = fs::metadata(&target)
            .await
            .map_err(|error| error.to_string())?;
        let end = start + chrono::Duration::milliseconds(duration_ms);
        let expires_at = self
            .camera
            .retention_days
            .map(|days| end + chrono::Duration::days(i64::from(days)));
        let relative = target
            .strip_prefix(&self.storage)
            .unwrap_or(&target)
            .to_string_lossy()
            .into_owned();

        sqlx::query(
            "INSERT INTO recordings(id,camera_id,event_id,start_time,end_time,file_path,file_size,container,duration_ms,expires_at) VALUES($1,$2,$3,$4,$5,$6,$7,'mp4',$8,$9) ON CONFLICT(file_path) DO UPDATE SET event_id=EXCLUDED.event_id,end_time=EXCLUDED.end_time,file_size=EXCLUDED.file_size,duration_ms=EXCLUDED.duration_ms,expires_at=EXCLUDED.expires_at",
        )
        .bind(Uuid::new_v4())
        .bind(&self.camera.id)
        .bind(self.event_id)
        .bind(start)
        .bind(end)
        .bind(relative)
        .bind(metadata.len() as i64)
        .bind(duration_ms)
        .bind(expires_at)
        .execute(&self.database)
        .await
        .map_err(|error| error.to_string())?;

        let pre_event_segments = self.pre_segments.len();
        let _ = fs::remove_dir_all(&self.work_dir).await;
        tracing::info!(
            camera_id=%self.camera.id,
            event_id=%self.event_id,
            path=%target.display(),
            duration_ms,
            pre_event_segments,
            used_prebuffer,
            "motion event finalized as a single recording"
        );
        Ok(target)
    }
}

async fn move_event_clip(source: &Path, target: &Path) -> Result<(), String> {
    if fs::try_exists(target).await.unwrap_or(false) {
        fs::remove_file(target)
            .await
            .map_err(|error| error.to_string())?;
    }
    fs::rename(source, target)
        .await
        .map_err(|error| error.to_string())
}

async fn concat_mp4s(inputs: &[PathBuf], target: &Path, work_dir: &Path) -> Result<(), String> {
    let list_path = work_dir.join("concat.txt");
    let mut list = String::new();
    for path in inputs {
        let escaped = path
            .to_string_lossy()
            .replace('\\', "\\\\")
            .replace('\'', "'\\''");
        list.push_str(&format!("file '{escaped}'\n"));
    }
    fs::write(&list_path, list)
        .await
        .map_err(|error| error.to_string())?;

    let temp_target = target.with_extension("mp4.partial");
    let _ = fs::remove_file(&temp_target).await;
    let output = Command::new("ffmpeg")
        .args([
            "-hide_banner",
            "-loglevel",
            "warning",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
        ])
        .arg(&list_path)
        .args(["-c", "copy", "-movflags", "+faststart", "-f", "mp4"])
        .arg(&temp_target)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .output()
        .await
        .map_err(|error| error.to_string())?;
    if !output.status.success() {
        let _ = fs::remove_file(&temp_target).await;
        return Err(String::from_utf8_lossy(&output.stderr).trim().to_string());
    }
    if fs::try_exists(target).await.unwrap_or(false) {
        fs::remove_file(target)
            .await
            .map_err(|error| error.to_string())?;
    }
    fs::rename(&temp_target, target)
        .await
        .map_err(|error| error.to_string())?;
    Ok(())
}

async fn probe_duration_ms(path: &Path) -> Option<i64> {
    let output = Command::new("ffprobe")
        .args([
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
        ])
        .arg(path)
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .await
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let seconds: f64 = String::from_utf8(output.stdout).ok()?.trim().parse().ok()?;
    let milliseconds = (seconds * 1000.0).round() as i64;
    (milliseconds > 0).then_some(milliseconds)
}
