use crate::recording::recorder::{CameraConfig, Recorder, RecorderError};
use sqlx::PgPool;
use std::path::PathBuf;
use thiserror::Error;
use tokio::process::Child;
use tokio::time::{Duration, Instant, sleep};

#[derive(Debug, Error)]
pub enum ConnectionError {
    #[error("unable to start recorder: {0}")]
    Start(#[from] RecorderError),
    #[error("FFmpeg exited before the RTSP stream became healthy")]
    EarlyExit,
    #[error("RTSP stream produced no encoded packets before the connection timeout")]
    Timeout,
}

pub async fn connect(
    config: &CameraConfig,
    storage_path: PathBuf,
    database: PgPool,
) -> Result<(Child, Recorder), ConnectionError> {
    let mut recorder = Recorder::new(config.clone(), storage_path, database);
    let mut child = recorder.start().await?;
    let deadline = Instant::now() + Duration::from_secs(12);
    loop {
        if child.try_wait().map_err(RecorderError::Storage)?.is_some() {
            return Err(ConnectionError::EarlyExit);
        }
        if recorder.has_received_packets().await {
            break;
        }
        if Instant::now() >= deadline {
            let _ = child.start_kill();
            let _ = child.wait().await;
            return Err(ConnectionError::Timeout);
        }
        sleep(Duration::from_millis(250)).await;
    }
    Ok((child, recorder))
}
