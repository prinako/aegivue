use super::paths::{camera_directory, segment_time};
use chrono::Local;
use sqlx::PgPool;
use std::{
    path::{Path, PathBuf},
    process::Stdio,
};
use thiserror::Error;
use tokio::{
    fs,
    process::{Child, Command},
    sync::Mutex,
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
    pub sub_stream: Option<String>,
    pub recording_enabled: bool,
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
    #[error("recording storage failure: {0}")]
    Storage(#[from] std::io::Error),
}

pub struct Recorder {
    camera: CameraConfig,
    storage: PathBuf,
    database: PgPool,
    segment_seconds: u64,
    pending_metadata: Mutex<Vec<PathBuf>>,
}

impl Recorder {
    pub fn new(
        camera: CameraConfig,
        storage: PathBuf,
        database: PgPool,
        segment_seconds: u64,
    ) -> Self {
        Self {
            camera,
            storage,
            database,
            segment_seconds,
            pending_metadata: Mutex::new(Vec::new()),
        }
    }

    pub async fn start(&self) -> Result<Child, RecorderError> {
        let camera_root = camera_directory(&self.storage, &self.camera.id, Local::now())
            .map_err(|error| std::io::Error::new(std::io::ErrorKind::InvalidInput, error))?
            .ancestors()
            .nth(4)
            .ok_or_else(|| std::io::Error::other("invalid camera directory"))?
            .to_path_buf();
        fs::create_dir_all(&camera_root).await?;
        self.ensure_directories().await?;
        self.recover_finalized_segments().await;

        let pattern = camera_root.join("%Y/%m/%d/%H/%H-%M-%S.mp4.partial");
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
                // Camera video is already H.264 in the common case, so keep it zero-copy.
                // Audio codecs such as G.711/PCM mu-law cannot be muxed directly into MP4;
                // transcode only the small audio stream to AAC for broad MP4 compatibility.
                "-c:v",
                "copy",
                "-c:a",
                "aac",
                "-f",
                "segment",
                "-segment_time",
                &self.segment_seconds.to_string(),
                "-reset_timestamps",
                "1",
                "-strftime",
                "1",
                "-segment_format",
                "mp4",
                "-segment_format_options",
                "movflags=+faststart",
            ])
            .arg(pattern)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::piped());
        command.spawn().map_err(RecorderError::Storage)
    }

    async fn ensure_directories(&self) -> Result<(), RecorderError> {
        let now = Local::now();
        let directory = camera_directory(&self.storage, &self.camera.id, now)
            .map_err(|error| std::io::Error::new(std::io::ErrorKind::InvalidInput, error))?;
        fs::create_dir_all(directory).await?;
        Ok(())
    }

    async fn recover_finalized_segments(&self) {
        let camera_root = self.storage.join(&self.camera.id);
        let mut stack = vec![camera_root];
        while let Some(directory) = stack.pop() {
            let mut entries = match fs::read_dir(&directory).await {
                Ok(entries) => entries,
                Err(_) => continue,
            };
            while let Ok(Some(entry)) = entries.next_entry().await {
                let path = entry.path();
                match entry.file_type().await {
                    Ok(kind) if kind.is_dir() => stack.push(path),
                    Ok(kind) if kind.is_file() && path.extension().is_some_and(|ext| ext == "mp4") => {
                        self.queue_metadata(path).await;
                    }
                    _ => {}
                }
            }
        }
        self.persist_segments(false).await;
    }

    async fn queue_metadata(&self, path: PathBuf) {
        let mut pending = self.pending_metadata.lock().await;
        if !pending.contains(&path) {
            pending.push(path);
        }
    }

    pub async fn persist_segments(&self, include_partial: bool) {
        let camera_root = self.storage.join(&self.camera.id);
        let mut stack = vec![camera_root];
        while let Some(directory) = stack.pop() {
            let mut entries = match fs::read_dir(&directory).await {
                Ok(entries) => entries,
                Err(_) => continue,
            };
            while let Ok(Some(entry)) = entries.next_entry().await {
                let path = entry.path();
                match entry.file_type().await {
                    Ok(kind) if kind.is_dir() => stack.push(path),
                    Ok(kind) if kind.is_file() => {
                        let file_name = path.file_name().and_then(|value| value.to_str()).unwrap_or("");
                        if file_name.ends_with(".mp4") || (include_partial && file_name.ends_with(".mp4.partial")) {
                            self.queue_metadata(path).await;
                        }
                    }
                    _ => {}
                }
            }
        }

        let paths = {
            let mut pending = self.pending_metadata.lock().await;
            std::mem::take(&mut *pending)
        };
        for path in paths {
            if let Err(error) = self.persist_segment(&path, include_partial).await {
                tracing::warn!(camera_id=%self.camera.id, path=%path.display(), %error, "unable to persist recording metadata");
                self.queue_metadata(path).await;
            }
        }
    }

    async fn persist_segment(&self, path: &Path, include_partial: bool) -> Result<(), std::io::Error> {
        let file_name = path.file_name().and_then(|value| value.to_str()).unwrap_or("");
        if file_name.ends_with(".partial") && !include_partial {
            return Ok(());
        }

        let metadata = fs::metadata(path).await?;
        if metadata.len() == 0 {
            return Ok(());
        }

        let finalized_path = if file_name.ends_with(".mp4.partial") {
            let final_path = path.with_file_name(file_name.trim_end_matches(".partial"));
            fs::rename(path, &final_path).await?;
            final_path
        } else {
            path.to_path_buf()
        };

        let relative = finalized_path
            .strip_prefix(&self.storage)
            .map_err(|error| std::io::Error::new(std::io::ErrorKind::InvalidInput, error))?;
        let start_time = segment_time(relative)
            .map_err(|error| std::io::Error::new(std::io::ErrorKind::InvalidData, error))?;
        let end_time = start_time + chrono::Duration::seconds(self.segment_seconds as i64);
        let size = fs::metadata(&finalized_path).await?.len() as i64;
        let file_path = relative.to_string_lossy().replace('\\', "/");

        sqlx::query(
            r#"
            INSERT INTO recordings (
                id, camera_id, start_time, end_time, file_path, file_size, container, created_at
            ) VALUES ($1, $2, $3, $4, $5, $6, 'mp4', now())
            ON CONFLICT (camera_id, file_path) DO UPDATE SET
                end_time = EXCLUDED.end_time,
                file_size = EXCLUDED.file_size
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(&self.camera.id)
        .bind(start_time)
        .bind(end_time)
        .bind(file_path)
        .bind(size)
        .execute(&self.database)
        .await
        .map_err(std::io::Error::other)?;
        Ok(())
    }

    pub async fn has_received_packets(&self) -> bool {
        let camera_root = self.storage.join(&self.camera.id);
        let mut stack = vec![camera_root];
        while let Some(directory) = stack.pop() {
            let mut entries = match fs::read_dir(&directory).await {
                Ok(entries) => entries,
                Err(_) => continue,
            };
            while let Ok(Some(entry)) = entries.next_entry().await {
                let path = entry.path();
                match entry.file_type().await {
                    Ok(kind) if kind.is_dir() => stack.push(path),
                    Ok(kind) if kind.is_file() => {
                        if fs::metadata(path).await.map(|metadata| metadata.len() > 0).unwrap_or(false) {
                            return true;
                        }
                    }
                    _ => {}
                }
            }
        }
        false
    }

    pub async fn finalize(&self) {
        self.persist_segments(true).await;
    }
}
