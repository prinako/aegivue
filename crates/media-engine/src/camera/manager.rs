use super::{commands::CameraCommand, worker::CameraWorker};
use crate::recording::recorder::CameraConfig;
use sqlx::PgPool;
use std::{collections::HashMap, path::PathBuf, sync::Arc};
use tokio::sync::{Mutex, mpsc, oneshot, watch};
use tokio_util::sync::CancellationToken;
use vigilo_common::CameraState;

struct WorkerHandle {
    commands: mpsc::Sender<CameraCommand>,
    status: watch::Receiver<CameraState>,
}
#[derive(Clone)]
pub struct CameraManager {
    workers: Arc<Mutex<HashMap<String, WorkerHandle>>>,
    database: PgPool,
    storage: PathBuf,
    shutdown: CancellationToken,
}

impl CameraManager {
    pub fn new(database: PgPool, storage: PathBuf, shutdown: CancellationToken) -> Self {
        Self {
            workers: Arc::new(Mutex::new(HashMap::new())),
            database,
            storage,
            shutdown,
        }
    }
    pub async fn start_enabled(&self) -> Result<(), sqlx::Error> {
        let ids = sqlx::query_scalar::<_, String>("SELECT id FROM cameras WHERE enabled")
            .fetch_all(&self.database)
            .await?;
        for id in ids {
            if let Err(error) = self.start(&id).await {
                tracing::error!(camera_id=%id,error=%error,"unable to restore camera");
            }
        }
        Ok(())
    }
    pub async fn start(&self, id: &str) -> Result<CameraState, String> {
        if let Some(handle) = self.workers.lock().await.get(id) {
            return Ok(*handle.status.borrow());
        }
        let camera=sqlx::query_as::<_,CameraConfig>("SELECT id,host,port,username,password_secret,main_stream FROM cameras WHERE id=$1 AND enabled").bind(id).fetch_optional(&self.database).await.map_err(|e|e.to_string())?.ok_or_else(||"enabled camera not found".to_string())?;
        let (tx, rx) = mpsc::channel(8);
        let (status_tx, status_rx) = watch::channel(CameraState::Starting);
        let worker = CameraWorker::new(
            camera,
            self.database.clone(),
            self.storage.clone(),
            rx,
            status_tx,
            self.shutdown.child_token(),
        );
        self.workers.lock().await.insert(
            id.to_string(),
            WorkerHandle {
                commands: tx,
                status: status_rx,
            },
        );
        tokio::spawn(async move {
            worker.run().await;
        });
        Ok(CameraState::Starting)
    }
    pub async fn stop(&self, id: &str) -> Result<CameraState, String> {
        let handle = self
            .workers
            .lock()
            .await
            .remove(id)
            .ok_or_else(|| "camera worker not found".to_string())?;
        handle
            .commands
            .send(CameraCommand::Stop)
            .await
            .map_err(|_| "camera worker stopped".to_string())?;
        Ok(CameraState::Stopping)
    }
    pub async fn status(&self, id: &str) -> CameraState {
        let workers = self.workers.lock().await;
        workers
            .get(id)
            .map(|h| *h.status.borrow())
            .unwrap_or(CameraState::Disabled)
    }
    pub async fn probe_status(&self, id: &str) -> Result<CameraState, String> {
        let sender = {
            let workers = self.workers.lock().await;
            workers
                .get(id)
                .map(|h| h.commands.clone())
                .ok_or_else(|| "camera worker not found".to_string())?
        };
        let (tx, rx) = oneshot::channel();
        sender
            .send(CameraCommand::Status(tx))
            .await
            .map_err(|_| "camera worker stopped".to_string())?;
        rx.await.map_err(|_| "camera worker stopped".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[tokio::test]
    async fn independent_worker_map_does_not_remove_others() {
        let workers: Arc<Mutex<HashMap<String, WorkerHandle>>> =
            Arc::new(Mutex::new(HashMap::new()));
        let (tx1, _) = mpsc::channel(1);
        let (_, rx1) = watch::channel(CameraState::Online);
        let (tx2, _) = mpsc::channel(1);
        let (_, rx2) = watch::channel(CameraState::Online);
        let mut guard = workers.lock().await;
        guard.insert(
            "one".into(),
            WorkerHandle {
                commands: tx1,
                status: rx1,
            },
        );
        guard.insert(
            "two".into(),
            WorkerHandle {
                commands: tx2,
                status: rx2,
            },
        );
        guard.remove("one");
        assert!(guard.contains_key("two"));
    }
}
