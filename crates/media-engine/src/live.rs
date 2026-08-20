use crate::{ffmpeg, recording::recorder::CameraConfig, rtsp};
use std::{env, path::PathBuf, process::Stdio, time::Duration};
use tokio::{
    process::{Child, Command},
    time::Instant,
};
use tokio_util::sync::CancellationToken;

fn live_root() -> PathBuf {
    PathBuf::from(env::var("AEGIVUE_LIVE_PATH").unwrap_or_else(|_| "/tmp/aegivue-live".into()))
}

fn percent_encode(value: &str) -> String {
    value
        .bytes()
        .map(|byte| match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' => {
                (byte as char).to_string()
            }
            _ => format!("%{byte:02X}"),
        })
        .collect()
}

fn rtsp_url(camera: &CameraConfig) -> String {
    let authority = match (&camera.username, &camera.password_secret) {
        (Some(user), Some(password)) => {
            format!("{}:{}@", percent_encode(user), percent_encode(password))
        }
        (Some(user), None) => format!("{}@", percent_encode(user)),
        _ => String::new(),
    };

    format!(
        "rtsp://{authority}{}:{}{}",
        camera.host,
        camera.port,
        live_stream(camera)
    )
}

fn live_stream(camera: &CameraConfig) -> &str {
    camera
        .sub_stream
        .as_deref()
        .map(str::trim)
        .filter(|stream| !stream.is_empty())
        .unwrap_or(&camera.main_stream)
}

fn publish_url(camera: &CameraConfig) -> String {
    let base = env::var("AEGIVUE_WEBRTC_PUBLISH_URL")
        .unwrap_or_else(|_| "rtsp://aegivue-webrtc:8554".into());
    format!("{}/{}", base.trim_end_matches('/'), camera.id)
}

pub async fn start(camera: &CameraConfig) -> Result<Child, std::io::Error> {
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
            "-fflags",
            "nobuffer",
            "-flags",
            "low_delay",
            "-i",
        ])
        .arg(rtsp_url(camera))
        .args([
            "-map",
            "0:v:0",
            "-an",
            "-c:v",
            "copy",
            "-f",
            "rtsp",
            "-rtsp_transport",
            "tcp",
        ])
        .arg(publish_url(camera))
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .kill_on_drop(true);

    command.spawn()
}

pub async fn supervise(camera: CameraConfig, shutdown: CancellationToken) {
    let mut attempt: u32 = 0;
    loop {
        if shutdown.is_cancelled() {
            break;
        }

        match start(&camera).await {
            Ok(mut child) => {
                ffmpeg::log_stderr(
                    &mut child,
                    &camera.id,
                    "live",
                    camera.username.as_deref(),
                    camera.password_secret.as_deref(),
                );
                tracing::info!(camera_id=%camera.id, "live WebRTC publisher started");
                let started = Instant::now();
                let exited = tokio::select! {
                    result = child.wait() => Some(result),
                    () = shutdown.cancelled() => {
                        ffmpeg::terminate(&mut child, &camera.id, "live").await;
                        None
                    }
                };
                let Some(result) = exited else {
                    break;
                };
                tracing::warn!(camera_id=%camera.id, ?result, "live publisher FFmpeg exited; restart scheduled");
                attempt = if started.elapsed() >= Duration::from_secs(30) {
                    1
                } else {
                    attempt.saturating_add(1)
                };
            }
            Err(error) => {
                attempt = attempt.saturating_add(1);
                tracing::warn!(camera_id=%camera.id, %error, "unable to start live WebRTC publisher; retry scheduled");
            }
        }

        let delay = rtsp::reconnect::delay(attempt);
        tracing::info!(camera_id=%camera.id, ?delay, "waiting to restart live publisher");
        tokio::select! {
            () = tokio::time::sleep(delay) => {}
            () = shutdown.cancelled() => break,
        }
    }
}

pub fn root() -> PathBuf {
    live_root()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn camera(sub_stream: Option<&str>) -> CameraConfig {
        CameraConfig {
            id: "front-door".into(),
            host: "camera.local".into(),
            port: 554,
            username: None,
            password_secret: None,
            main_stream: "/main".into(),
            sub_stream: sub_stream.map(str::to_owned),
            recording_enabled: false,
            retention_days: None,
            motion_enabled: false,
            motion_stream: "sub".into(),
            motion_fps: 5.0,
            motion_sensitivity: 0.65,
        }
    }

    #[test]
    fn live_preview_prefers_configured_substream() {
        assert_eq!(live_stream(&camera(Some("/sub"))), "/sub");
    }

    #[test]
    fn live_preview_falls_back_to_main_stream() {
        assert_eq!(live_stream(&camera(None)), "/main");
        assert_eq!(live_stream(&camera(Some("  "))), "/main");
    }
}
