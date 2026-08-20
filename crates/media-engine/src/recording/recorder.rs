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
    pub retention_days: Option<i32>,
    pub motion_enabled: bool,
    pub motion_stream: String,
    pub motion_fps: f64,
    pub motion_sensitivity: f64,
}

impl CameraConfig {
    pub(crate) fn rtsp_url(&self) -> String {
        self.rtsp_url_for_stream("main")
    }

    pub(crate) fn motion_rtsp_url(&self) -> String {
        self.rtsp_url_for_stream(&self.motion_stream)
    }

    fn rtsp_url_for_stream(&self, stream: &str) -> String {
        let authority = match (&self.username, &self.password_secret) {
            (Some(user), Some(password)) => {
                format!("{}:{}@", percent_encode(user), percent_encode(password))
            }
            (Some(user), None) => format!("{}@", percent_encode(user)),
            _ => String::new(),
        };
        let path = if stream == "sub" {
            self.sub_stream.as_deref().unwrap_or(&self.main_stream)
        } else {
            &self.main_stream
        };
        format!("rtsp://{authority}{}:{}{path}", self.host, self.port)
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
                "-y",
            ])
            .arg(pattern)
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::piped());

        let mut child = command.spawn()?;
        crate::ffmpeg::log_stderr(
            &mut child,
            &self.camera.id,
            "recording",
            self.camera.username.as_deref(),
            self.camera.password_secret.as_deref(),
        );
        Ok(child)
    }

    pub async fn persist_segments(&self, include_current: bool) {
        if let Err(error) = self.persist_segments_inner(include_current).await {
            tracing::warn!(camera_id=%self.camera.id, %error, "unable to persist recording metadata");
        }
    }

    pub async fn finalize(&self) {
        self.persist_segments(true).await;
    }

    async fn ensure_directories(&self) -> Result<(), std::io::Error> {
        let now = Local::now();
        for offset in 0..=1 {
            let time = now + chrono::Duration::hours(offset);
            let path = camera_directory(&self.storage, &self.camera.id, time)
                .map_err(|error| std::io::Error::new(std::io::ErrorKind::InvalidInput, error))?;
            fs::create_dir_all(path).await?;
        }
        Ok(())
    }

    async fn recover_finalized_segments(&self) {
        let camera_root = self.storage.join(&self.camera.id);
        let mut stack = vec![camera_root];
        while let Some(directory) = stack.pop() {
            let Ok(mut entries) = fs::read_dir(&directory).await else {
                continue;
            };
            while let Ok(Some(entry)) = entries.next_entry().await {
                let path = entry.path();
                if path.is_dir() {
                    stack.push(path);
                } else if path.extension().and_then(|value| value.to_str()) == Some("mp4") {
                    self.pending_metadata.lock().await.push(path);
                }
            }
        }
        self.flush_pending().await;
    }

    async fn persist_segments_inner(&self, include_current: bool) -> Result<(), std::io::Error> {
        self.ensure_directories().await?;
        let camera_root = self.storage.join(&self.camera.id);
        let mut partials = Vec::new();
        let mut stack = vec![camera_root];
        while let Some(directory) = stack.pop() {
            let Ok(mut entries) = fs::read_dir(&directory).await else {
                continue;
            };
            while let Some(entry) = entries.next_entry().await? {
                let path = entry.path();
                if path.is_dir() {
                    stack.push(path);
                } else if path.extension().and_then(|value| value.to_str()) == Some("partial") {
                    partials.push(path);
                }
            }
        }
        partials.sort();
        let finalize_count = if include_current {
            partials.len()
        } else {
            partials.len().saturating_sub(1)
        };
        for partial in partials.into_iter().take(finalize_count) {
            let metadata = fs::metadata(&partial).await?;
            if metadata.len() == 0 {
                let _ = fs::remove_file(&partial).await;
                continue;
            }
            let final_path = partial.with_extension("");
            fs::rename(&partial, &final_path).await?;
            self.pending_metadata.lock().await.push(final_path);
        }
        self.flush_pending().await;
        Ok(())
    }

    async fn flush_pending(&self) {
        let pending = {
            let mut guard = self.pending_metadata.lock().await;
            std::mem::take(&mut *guard)
        };
        let mut failed = Vec::new();
        for path in pending {
            if let Err(error) = self.persist_one(&path).await {
                tracing::warn!(camera_id=%self.camera.id,path=%path.display(),%error,"unable to index finalized recording");
                failed.push(path);
            }
        }
        if !failed.is_empty() {
            self.pending_metadata.lock().await.extend(failed);
        }
    }

    async fn persist_one(&self, path: &Path) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let start = segment_time(path)?;
        let metadata = fs::metadata(path).await?;
        let duration_ms = self.segment_seconds.saturating_mul(1000) as i64;
        let end = start + chrono::Duration::milliseconds(duration_ms);
        let expires_at = self
            .camera
            .retention_days
            .map(|days| end + chrono::Duration::days(i64::from(days)));
        let id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO recordings(
                id,
                camera_id,
                start_time,
                end_time,
                file_path,
                file_size,
                container,
                duration_ms,
                expires_at
            )
            VALUES($1,$2,$3,$4,$5,$6,'mp4',$7,$8)
            ON CONFLICT(file_path) DO NOTHING
            "#,
        )
        .bind(id)
        .bind(&self.camera.id)
        .bind(start)
        .bind(end)
        .bind(path.to_string_lossy().as_ref())
        .bind(metadata.len() as i64)
        .bind(duration_ms)
        .bind(expires_at)
        .execute(&self.database)
        .await?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn percent_encoding_hides_reserved_credentials() {
        assert_eq!(percent_encode("a:b@c"), "a%3Ab%40c");
    }

    #[test]
    fn motion_stream_prefers_configured_substream() {
        let camera = CameraConfig {
            id: "cam-one".into(),
            host: "camera".into(),
            port: 554,
            username: None,
            password_secret: None,
            main_stream: "/main".into(),
            sub_stream: Some("/sub".into()),
            recording_enabled: true,
            retention_days: Some(30),
            motion_enabled: true,
            motion_stream: "sub".into(),
            motion_fps: 5.0,
            motion_sensitivity: 0.65,
        };
        assert_eq!(camera.motion_rtsp_url(), "rtsp://camera:554/sub");
    }
}
