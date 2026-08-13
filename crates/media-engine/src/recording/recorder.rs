use super::paths::camera_directory;
use chrono::{DateTime, Utc};
use sqlx::PgPool;
use std::{path::PathBuf, process::Stdio};
use thiserror::Error;
use tokio::{
    fs,
    process::{Child, Command},
};
use uuid::Uuid;

#[derive(Debug, Clone, sqlx::FromRow)]
pub struct CameraConfig {
    pub id: String,
    pub host: String,
    pub port: i32,
    pub username: Option<String>,
    pub password_secret: Option<String>,
    pub main_stream: String,
}

impl CameraConfig {
    fn rtsp_url(&self) -> String {
        let authority = match (&self.username, &self.password_secret) {
            (Some(user), Some(password)) => {
                format!("{}:{}@", percent_encode(user), percent_encode(password))
            }
            (Some(user), None) => format!("{}@", percent_encode(user)),
            _ => String::new(),
        };
        format!(
            "rtsp://{authority}{}:{}{}",
            self.host, self.port, self.main_stream
        )
    }
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

#[derive(Debug, Error)]
pub enum RecorderError {
    #[error("unable to prepare recording directory: {0}")]
    Storage(#[from] std::io::Error),
}

pub struct Recorder {
    camera: CameraConfig,
    storage: PathBuf,
    database: PgPool,
    started_at: DateTime<Utc>,
    directory: PathBuf,
}

impl Recorder {
    pub fn new(camera: CameraConfig, storage: PathBuf, database: PgPool) -> Self {
        Self {
            camera,
            storage,
            database,
            started_at: Utc::now(),
            directory: PathBuf::new(),
        }
    }

    pub async fn start(&mut self) -> Result<Child, RecorderError> {
        self.started_at = Utc::now();
        self.directory = camera_directory(&self.storage, &self.camera.id, self.started_at)
            .map_err(|error| std::io::Error::new(std::io::ErrorKind::InvalidInput, error))?;
        fs::create_dir_all(&self.directory).await?;
        let pattern = self.directory.join("%H-%M-%S.mp4");
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
            .arg(self.camera.rtsp_url())
            .args([
                "-map",
                "0:v:0",
                "-map",
                "0:a?",
                "-c",
                "copy",
                "-f",
                "segment",
                "-segment_time",
                "60",
                "-segment_atclocktime",
                "1",
                "-reset_timestamps",
                "1",
                "-strftime",
                "1",
                "-movflags",
                "+faststart",
            ])
            .arg(pattern)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .kill_on_drop(true);
        Ok(command.spawn()?)
    }

    pub async fn has_received_packets(&self) -> bool {
        let Ok(mut entries) = fs::read_dir(&self.directory).await else {
            return false;
        };
        while let Ok(Some(entry)) = entries.next_entry().await {
            if entry.path().extension().and_then(|value| value.to_str()) == Some("mp4")
                && entry
                    .metadata()
                    .await
                    .is_ok_and(|metadata| metadata.len() > 0)
            {
                return true;
            }
        }
        false
    }

    pub async fn persist_segments(&self, include_latest: bool) {
        let Ok(mut entries) = fs::read_dir(&self.directory).await else {
            return;
        };
        let mut files = Vec::new();
        while let Ok(Some(entry)) = entries.next_entry().await {
            let path = entry.path();
            if path.extension().and_then(|value| value.to_str()) != Some("mp4") {
                continue;
            }
            files.push(entry);
        }
        files.sort_by_key(|entry| entry.file_name());
        if !include_latest {
            files.pop();
        }
        for entry in files {
            let path = entry.path();
            let Ok(metadata) = entry.metadata().await else {
                continue;
            };
            let end = metadata
                .modified()
                .ok()
                .map(DateTime::<Utc>::from)
                .unwrap_or_else(Utc::now);
            let relative = path
                .strip_prefix(&self.storage)
                .unwrap_or(&path)
                .to_string_lossy()
                .into_owned();
            if let Err(error) = sqlx::query("INSERT INTO recordings(id,camera_id,start_time,end_time,file_path,file_size,container,duration_ms) VALUES($1,$2,$3,$4,$5,$6,'mp4',$7) ON CONFLICT(file_path) DO NOTHING")
                .bind(Uuid::new_v4()).bind(&self.camera.id).bind(self.started_at).bind(end).bind(relative).bind(metadata.len() as i64).bind((end-self.started_at).num_milliseconds().max(0)).execute(&self.database).await {
                tracing::error!(camera_id=%self.camera.id, error=%error, "unable to persist recording metadata");
            }
        }
    }

    pub async fn finalize(&self) {
        self.persist_segments(true).await;
    }
}
