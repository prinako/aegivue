use super::paths::{camera_directory, segment_time};
use chrono::Utc;
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
        let camera_root = camera_directory(&self.storage, &self.camera.id, Utc::now())
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
                "-c",
                "copy",
                "-f",
                "segment",
                "-segment_format",
                "mp4",
                "-segment_time",
            ])
            .arg(self.segment_seconds.to_string())
            .args([
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
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .kill_on_drop(true);
        Ok(command.spawn()?)
    }

    async fn files_with_suffix(&self, suffix: &str) -> Vec<PathBuf> {
        let root = self.storage.join(&self.camera.id);
        let mut pending = vec![root];
        let mut files = Vec::new();
        while let Some(directory) = pending.pop() {
            let Ok(mut entries) = fs::read_dir(directory).await else {
                continue;
            };
            while let Ok(Some(entry)) = entries.next_entry().await {
                let path = entry.path();
                if entry.file_type().await.is_ok_and(|kind| kind.is_dir()) {
                    pending.push(path);
                } else if path.to_string_lossy().ends_with(suffix) {
                    files.push(path);
                }
            }
        }
        files.sort();
        files
    }

    async fn partial_files(&self) -> Vec<PathBuf> {
        self.files_with_suffix(".mp4.partial").await
    }

    async fn finalized_files(&self) -> Vec<PathBuf> {
        self.files_with_suffix(".mp4").await
    }

    pub async fn has_received_packets(&self) -> bool {
        for path in self.partial_files().await {
            if fs::metadata(path)
                .await
                .is_ok_and(|metadata| metadata.len() > 0)
            {
                return true;
            }
        }
        false
    }

    pub async fn persist_segments(&self, include_latest: bool) {
        if let Err(error) = self.ensure_directories().await {
            tracing::error!(camera_id=%self.camera.id, %error, "unable to prepare current recording directories");
            return;
        }
        self.retry_pending_metadata().await;

        let mut files = self.partial_files().await;
        if !include_latest {
            files.pop();
        }
        for partial in files {
            self.finalize_segment(&partial).await;
        }
    }

    async fn finalize_segment(&self, partial: &Path) {
        let Ok(metadata) = fs::metadata(partial).await else {
            return;
        };
        if metadata.len() == 0 {
            tracing::warn!(camera_id=%self.camera.id, path=%partial.display(), "discarding empty partial segment");
            let _ = fs::remove_file(partial).await;
            return;
        }
        let Some(start) = segment_time(&self.storage, &self.camera.id, partial) else {
            tracing::error!(camera_id=%self.camera.id, path=%partial.display(), "invalid segment path");
            return;
        };
        let Some(duration_ms) = probe_duration_ms(partial).await else {
            tracing::warn!(camera_id=%self.camera.id, path=%partial.display(), "partial segment is not a valid playable MP4");
            return;
        };
        let final_path = PathBuf::from(partial.to_string_lossy().trim_end_matches(".partial"));
        if let Err(error) = fs::rename(partial, &final_path).await {
            tracing::error!(camera_id=%self.camera.id, error=%error, "unable to atomically finalize segment");
            return;
        }
        if let Err(error) = self
            .insert_recording_metadata(&final_path, metadata.len(), start, duration_ms)
            .await
        {
            tracing::error!(camera_id=%self.camera.id, path=%final_path.display(), %error, "unable to persist finalized segment metadata; queued for retry");
            self.queue_metadata_retry(final_path).await;
        }
    }

    async fn insert_recording_metadata(
        &self,
        final_path: &Path,
        file_size: u64,
        start: chrono::DateTime<Utc>,
        duration_ms: i64,
    ) -> Result<(), sqlx::Error> {
        let end = start + chrono::Duration::milliseconds(duration_ms);
        let relative = final_path
            .strip_prefix(&self.storage)
            .unwrap_or(final_path)
            .to_string_lossy()
            .into_owned();
        sqlx::query("INSERT INTO recordings(id,camera_id,start_time,end_time,file_path,file_size,container,duration_ms) VALUES($1,$2,$3,$4,$5,$6,'mp4',$7) ON CONFLICT(file_path) DO NOTHING")
            .bind(Uuid::new_v4())
            .bind(&self.camera.id)
            .bind(start)
            .bind(end)
            .bind(relative)
            .bind(file_size as i64)
            .bind(duration_ms)
            .execute(&self.database)
            .await?;
        Ok(())
    }

    async fn queue_metadata_retry(&self, path: PathBuf) {
        let mut pending = self.pending_metadata.lock().await;
        if !pending.contains(&path) {
            pending.push(path);
        }
    }

    async fn retry_pending_metadata(&self) {
        let paths = {
            let mut pending = self.pending_metadata.lock().await;
            std::mem::take(&mut *pending)
        };
        for path in paths {
            if let Err(error) = self.recover_finalized_file(&path).await {
                tracing::warn!(camera_id=%self.camera.id, path=%path.display(), %error, "recording metadata retry deferred");
                self.queue_metadata_retry(path).await;
            }
        }
    }

    async fn recover_finalized_segments(&self) {
        for path in self.finalized_files().await {
            if let Err(error) = self.recover_finalized_file(&path).await {
                tracing::warn!(camera_id=%self.camera.id, path=%path.display(), %error, "unable to reconcile finalized recording metadata");
                self.queue_metadata_retry(path).await;
            }
        }
    }

    async fn recover_finalized_file(&self, path: &Path) -> Result<(), String> {
        let relative = path
            .strip_prefix(&self.storage)
            .unwrap_or(path)
            .to_string_lossy()
            .into_owned();
        let exists = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM recordings WHERE file_path=$1)",
        )
        .bind(&relative)
        .fetch_one(&self.database)
        .await
        .map_err(|error| error.to_string())?;
        if exists {
            return Ok(());
        }

        let metadata = fs::metadata(path).await.map_err(|error| error.to_string())?;
        if metadata.len() == 0 {
            return Err("finalized recording is empty".to_string());
        }
        let start = segment_time(&self.storage, &self.camera.id, path)
            .ok_or_else(|| "invalid finalized segment path".to_string())?;
        let duration_ms = probe_duration_ms(path)
            .await
            .ok_or_else(|| "finalized recording is not a playable MP4".to_string())?;
        self.insert_recording_metadata(path, metadata.len(), start, duration_ms)
            .await
            .map_err(|error| error.to_string())
    }

    pub async fn finalize(&self) {
        self.persist_segments(true).await;
        self.retry_pending_metadata().await;
    }

    async fn ensure_directories(&self) -> Result<(), std::io::Error> {
        let now = Utc::now();
        for at in [now, now + chrono::Duration::hours(1)] {
            let directory = camera_directory(&self.storage, &self.camera.id, at)
                .map_err(|error| std::io::Error::new(std::io::ErrorKind::InvalidInput, error))?;
            fs::create_dir_all(directory).await?;
        }
        Ok(())
    }
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

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    #[test]
    fn sequential_segments_have_individual_duration() {
        let starts = [0, 60, 120].map(|seconds| Utc.timestamp_opt(seconds, 0).unwrap());
        for start in starts {
            assert_eq!(
                (start + chrono::Duration::seconds(60) - start).num_seconds(),
                60
            );
        }
    }
}
