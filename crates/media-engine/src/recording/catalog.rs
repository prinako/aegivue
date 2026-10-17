use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::{path::PathBuf, time::Duration};
use thiserror::Error;
use tokio::{fs, io::AsyncWriteExt};
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

const RETRY_INTERVAL: Duration = Duration::from_secs(30);

#[derive(Clone)]
pub struct RecordingCatalog {
    database: PgPool,
    storage: PathBuf,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct RecordingMetadata {
    pub id: Uuid,
    pub camera_id: String,
    pub event_id: Option<Uuid>,
    pub start_time: DateTime<Utc>,
    pub end_time: DateTime<Utc>,
    pub file_path: String,
    pub file_size: i64,
    pub duration_ms: i64,
    pub expires_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Error)]
pub enum CatalogError {
    #[error("recording catalog storage failure: {0}")]
    Storage(#[from] std::io::Error),
    #[error("recording catalog serialization failure: {0}")]
    Serialization(#[from] serde_json::Error),
    #[error("recording catalog database failure: {0}")]
    Database(#[from] sqlx::Error),
}

impl RecordingCatalog {
    pub fn new(database: PgPool, storage: PathBuf) -> Self {
        Self { database, storage }
    }

    pub async fn persist(&self, metadata: &RecordingMetadata) -> Result<(), CatalogError> {
        let pending = self.stage(metadata).await?;
        self.persist_database(metadata).await?;
        if let Err(error) = fs::remove_file(&pending).await
            && error.kind() != std::io::ErrorKind::NotFound
        {
            tracing::warn!(path=%pending.display(), %error, "unable to remove persisted recording metadata sidecar");
        }
        Ok(())
    }

    pub async fn contains_path(&self, file_path: &str) -> Result<bool, sqlx::Error> {
        sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM recordings WHERE file_path=$1)")
            .bind(file_path)
            .fetch_one(&self.database)
            .await
    }

    pub async fn recover_pending(&self) -> Result<usize, std::io::Error> {
        let directory = self.pending_directory();
        let mut entries = match fs::read_dir(&directory).await {
            Ok(entries) => entries,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(0),
            Err(error) => return Err(error),
        };
        let mut recovered = 0;
        while let Some(entry) = entries.next_entry().await? {
            let path = entry.path();
            if path.extension().and_then(|value| value.to_str()) != Some("json") {
                continue;
            }
            let metadata: RecordingMetadata = match fs::read(&path)
                .await
                .map_err(CatalogError::from)
                .and_then(|bytes| serde_json::from_slice(&bytes).map_err(CatalogError::from))
            {
                Ok(metadata) => metadata,
                Err(error) => {
                    tracing::error!(path=%path.display(), %error, "unable to read pending recording metadata");
                    continue;
                }
            };
            if !safe_relative_path(&metadata.file_path)
                || !fs::try_exists(self.storage.join(&metadata.file_path))
                    .await
                    .unwrap_or(false)
            {
                tracing::error!(path=%path.display(), file_path=%metadata.file_path, "pending recording file is missing or unsafe");
                continue;
            }
            match self.persist_database(&metadata).await {
                Ok(()) => {
                    if fs::remove_file(&path).await.is_ok() {
                        recovered += 1;
                    }
                }
                Err(error) => {
                    tracing::warn!(path=%path.display(), %error, "recording metadata recovery deferred");
                }
            }
        }
        Ok(recovered)
    }

    async fn stage(&self, metadata: &RecordingMetadata) -> Result<PathBuf, CatalogError> {
        let directory = self.pending_directory();
        fs::create_dir_all(&directory).await?;
        let pending = directory.join(format!("{}.json", metadata.id));
        let temporary = directory.join(format!("{}.{}.tmp", metadata.id, Uuid::new_v4()));
        let mut file = fs::File::create(&temporary).await?;
        file.write_all(&serde_json::to_vec(metadata)?).await?;
        file.sync_all().await?;
        drop(file);
        fs::rename(&temporary, &pending).await?;
        Ok(pending)
    }

    async fn persist_database(&self, metadata: &RecordingMetadata) -> Result<(), sqlx::Error> {
        sqlx::query(
            r#"
            INSERT INTO recordings(
                id, camera_id, event_id, start_time, end_time, file_path,
                file_size, container, duration_ms, expires_at
            )
            VALUES($1,$2,$3,$4,$5,$6,$7,'mp4',$8,$9)
            ON CONFLICT(file_path) DO NOTHING
            "#,
        )
        .bind(metadata.id)
        .bind(&metadata.camera_id)
        .bind(metadata.event_id)
        .bind(metadata.start_time)
        .bind(metadata.end_time)
        .bind(&metadata.file_path)
        .bind(metadata.file_size)
        .bind(metadata.duration_ms)
        .bind(metadata.expires_at)
        .execute(&self.database)
        .await?;
        Ok(())
    }

    fn pending_directory(&self) -> PathBuf {
        self.storage.join(".metadata-pending")
    }
}

pub async fn supervise(database: PgPool, storage: PathBuf, shutdown: CancellationToken) {
    let catalog = RecordingCatalog::new(database, storage);
    let mut interval = tokio::time::interval(RETRY_INTERVAL);
    interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        tokio::select! {
            _ = interval.tick() => match catalog.recover_pending().await {
                Ok(recovered) if recovered > 0 => tracing::info!(recovered, "recovered pending recording metadata"),
                Ok(_) => {}
                Err(error) => tracing::error!(%error, "unable to scan pending recording metadata"),
            },
            () = shutdown.cancelled() => break,
        }
    }
}

fn safe_relative_path(value: &str) -> bool {
    let path = std::path::Path::new(value);
    !path.is_absolute()
        && !path
            .components()
            .any(|component| matches!(component, std::path::Component::ParentDir))
}
