use crate::recording::recorder::CameraConfig;
use std::{env, path::PathBuf, process::Stdio};
use tokio::{fs, process::{Child, Command}};

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
        (Some(user), Some(password)) => format!(
            "{}:{}@",
            percent_encode(user),
            percent_encode(password)
        ),
        (Some(user), None) => format!("{}@", percent_encode(user)),
        _ => String::new(),
    };

    format!(
        "rtsp://{authority}{}:{}{}",
        camera.host, camera.port, camera.main_stream
    )
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

pub fn root() -> PathBuf {
    live_root()
}
