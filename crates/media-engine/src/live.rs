use crate::{ffmpeg, recording::recorder::CameraConfig, rtsp};
use std::{env, path::PathBuf, process::Stdio, time::Duration};
use tokio::{
    fs,
    process::{Child, Command},
    time::Instant,
};
use tokio_util::sync::CancellationToken;

fn live_root() -> PathBuf {
    PathBuf::from(env::var("VIGILO_LIVE_PATH").unwrap_or_else(|_| "/tmp/vigilo-live".into()))
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

pub async fn start(camera: &CameraConfig) -> Result<Child, std::io::Error> {
    let directory = live_root().join(&camera.id);
    let _ = fs::remove_dir_all(&directory).await;
    fs::create_dir_all(&directory).await?;

    let playlist = directory.join("index.m3u8");
    let segments = directory.join("segment-%06d.ts");

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
            "hls",
            "-hls_time",
            "2",
            "-hls_list_size",
            "4",
            "-hls_delete_threshold",
            "2",
            "-hls_flags",
            "delete_segments+append_list+omit_endlist+independent_segments",
            "-hls_segment_filename",
        ])
        .arg(segments)
        .arg(playlist)
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
                tracing::info!(camera_id=%camera.id, "live HLS preview started");
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
                tracing::warn!(camera_id=%camera.id, ?result, "live HLS FFmpeg exited; preview restart scheduled");
                attempt = if started.elapsed() >= Duration::from_secs(30) {
                    1
                } else {
                    attempt.saturating_add(1)
                };
            }
            Err(error) => {
                attempt = attempt.saturating_add(1);
                tracing::warn!(camera_id=%camera.id, %error, "unable to start live HLS preview; retry scheduled");
            }
        }

        let delay = rtsp::reconnect::delay(attempt);
        tracing::info!(camera_id=%camera.id, ?delay, "waiting to restart live HLS preview");
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
