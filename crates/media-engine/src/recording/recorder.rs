use super::{
    catalog::{CatalogError, RecordingCatalog, RecordingMetadata},
    paths::{camera_directory, segment_time},
};
use chrono::{Local, Utc};
use sqlx::PgPool;
use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    process::Stdio,
    sync::Arc,
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

#[derive(Clone)]
pub struct Recorder {
    camera: CameraConfig,
    storage: PathBuf,
    catalog: RecordingCatalog,
    segment_seconds: u64,
    packet_baseline: Arc<Mutex<Option<HashMap<PathBuf, u64>>>>,
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
            catalog: RecordingCatalog::new(database, storage.clone()),
            storage,
            segment_seconds,
            packet_baseline: Arc::new(Mutex::new(None)),
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
                "-b:a",
                "64k",
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
        let now = Local::now();
        let mut files = Vec::new();
        for at in [now, now - chrono::Duration::hours(1)] {
            let Ok(directory) = camera_directory(&self.storage, &self.camera.id, at) else {
                continue;
            };
            let Ok(mut entries) = fs::read_dir(directory).await else {
                continue;
            };
            while let Ok(Some(entry)) = entries.next_entry().await {
                let path = entry.path();
                if path.to_string_lossy().ends_with(".mp4.partial") {
                    files.push(path);
                }
            }
        }
        files.sort();
        files.dedup();
        files
    }

    async fn finalized_files(&self) -> Vec<PathBuf> {
        self.files_with_suffix(".mp4").await
    }

    pub async fn has_received_packets(&self) -> bool {
        let mut current = HashMap::new();
        for path in self.partial_files().await {
            if let Ok(metadata) = fs::metadata(&path).await {
                current.insert(path, metadata.len());
            }
        }

        let mut baseline = self.packet_baseline.lock().await;
        let Some(initial) = baseline.as_ref() else {
            *baseline = Some(current);
            return false;
        };

        current
            .iter()
            .any(|(path, size)| *size > 0 && *size > initial.get(path).copied().unwrap_or_default())
    }

    pub async fn persist_segments(&self, include_latest: bool) {
        if let Err(error) = self.ensure_directories().await {
            tracing::error!(camera_id=%self.camera.id, %error, "unable to prepare current recording directories");
            return;
        }
        let mut files = if include_latest {
            self.files_with_suffix(".mp4.partial").await
        } else {
            self.partial_files().await
        };
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
            tracing::error!(camera_id=%self.camera.id, path=%final_path.display(), %error, "unable to persist finalized segment metadata; durable retry staged");
        }
    }

    async fn insert_recording_metadata(
        &self,
        final_path: &Path,
        file_size: u64,
        start: chrono::DateTime<Local>,
        duration_ms: i64,
    ) -> Result<(), CatalogError> {
        let end = start + chrono::Duration::milliseconds(duration_ms);
        let expires_at = self
            .camera
            .retention_days
            .map(|days| end + chrono::Duration::days(i64::from(days)));
        let relative = final_path
            .strip_prefix(&self.storage)
            .unwrap_or(final_path)
            .to_string_lossy()
            .into_owned();
        self.catalog
            .persist(&RecordingMetadata {
                id: Uuid::new_v4(),
                camera_id: self.camera.id.clone(),
                event_id: None,
                start_time: start.with_timezone(&Utc),
                end_time: end.with_timezone(&Utc),
                file_path: relative,
                file_size: file_size as i64,
                duration_ms,
                expires_at: expires_at.map(|value| value.with_timezone(&Utc)),
            })
            .await
    }

    async fn recover_finalized_segments(&self) {
        for path in self.finalized_files().await {
            if let Err(error) = self.recover_finalized_file(&path).await {
                tracing::warn!(camera_id=%self.camera.id, path=%path.display(), %error, "unable to reconcile finalized recording metadata");
            }
            tokio::task::yield_now().await;
        }
    }

    async fn recover_stale_partial_segments(&self) {
        let cutoff = Local::now() - chrono::Duration::hours(2);
        for path in self.files_with_suffix(".mp4.partial").await {
            if segment_time(&self.storage, &self.camera.id, &path).is_some_and(|at| at < cutoff) {
                self.finalize_segment(&path).await;
            }
            tokio::task::yield_now().await;
        }
    }

    async fn recover_finalized_file(&self, path: &Path) -> Result<(), String> {
        let relative = path
            .strip_prefix(&self.storage)
            .unwrap_or(path)
            .to_string_lossy()
            .into_owned();
        let exists = self
            .catalog
            .contains_path(&relative)
            .await
            .map_err(|error| error.to_string())?;
        if exists {
            return Ok(());
        }

        let metadata = fs::metadata(path)
            .await
            .map_err(|error| error.to_string())?;
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
    }

    async fn ensure_directories(&self) -> Result<(), std::io::Error> {
        let now = Local::now();
        for at in [now, now + chrono::Duration::hours(1)] {
            let directory = camera_directory(&self.storage, &self.camera.id, at)
                .map_err(|error| std::io::Error::new(std::io::ErrorKind::InvalidInput, error))?;
            fs::create_dir_all(directory).await?;
        }
        Ok(())
    }
}

pub fn recover_in_background(
    camera: CameraConfig,
    storage: PathBuf,
    database: PgPool,
    segment_seconds: u64,
) {
    tokio::spawn(async move {
        let recorder = Recorder::new(camera, storage, database, segment_seconds);
        recorder.recover_finalized_segments().await;
        recorder.recover_stale_partial_segments().await;
    });
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
    use crate::recording::paths::segment_path;
    use chrono::TimeZone;
    use tokio::io::AsyncWriteExt;

    #[test]
    fn recording_always_uses_main_stream() {
        let camera = CameraConfig {
            id: "front-door".into(),
            host: "camera.local".into(),
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
        assert_eq!(camera.rtsp_url(), "rtsp://camera.local:554/main");
        assert_eq!(camera.motion_rtsp_url(), "rtsp://camera.local:554/sub");
    }

    #[test]
    fn sequential_segments_have_individual_duration() {
        let starts = [0, 60, 120].map(|seconds| Local.timestamp_opt(seconds, 0).unwrap());
        for start in starts {
            assert_eq!(
                (start + chrono::Duration::seconds(60) - start).num_seconds(),
                60
            );
        }
    }

    #[tokio::test]
    async fn packet_probe_ignores_partial_files_that_predate_connection() {
        let root = std::env::temp_dir().join(format!("aegivue-probe-{}", Uuid::new_v4()));
        let current = segment_path(&root, "front-door", Local::now()).unwrap();
        let partial = PathBuf::from(format!("{}.partial", current.display()));
        fs::create_dir_all(partial.parent().unwrap()).await.unwrap();
        fs::write(&partial, b"stale").await.unwrap();
        let recorder = Recorder::new(
            CameraConfig {
                id: "front-door".into(),
                host: "camera.local".into(),
                port: 554,
                username: None,
                password_secret: None,
                main_stream: "/main".into(),
                sub_stream: None,
                recording_enabled: true,
                retention_days: None,
                motion_enabled: false,
                motion_stream: "sub".into(),
                motion_fps: 5.0,
                motion_sensitivity: 0.65,
            },
            root.clone(),
            PgPool::connect_lazy("postgres://localhost/aegivue").unwrap(),
            60,
        );

        assert!(!recorder.has_received_packets().await);
        let mut file = fs::OpenOptions::new()
            .append(true)
            .open(&partial)
            .await
            .unwrap();
        file.write_all(b"new-packets").await.unwrap();
        file.flush().await.unwrap();
        assert!(recorder.has_received_packets().await);

        fs::remove_dir_all(root).await.unwrap();
    }
}
