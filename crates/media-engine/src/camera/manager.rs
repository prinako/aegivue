use super::{commands::CameraCommand, worker::CameraWorker};
use crate::recording::recorder::CameraConfig;
use aegivue_common::CameraState;
use sqlx::PgPool;
use std::{collections::HashMap, path::PathBuf, sync::Arc};
use tokio::{
    sync::{Mutex, mpsc, oneshot, watch},
    task::JoinHandle,
};
use tokio_util::sync::CancellationToken;

struct WorkerHandle {
    commands: mpsc::Sender<CameraCommand>,
    status: watch::Receiver<CameraState>,
    task: JoinHandle<()>,
}

#[derive(Clone)]
pub struct CameraManager {
    workers: Arc<Mutex<HashMap<String, WorkerHandle>>>,
    lifecycle_locks: Arc<Mutex<HashMap<String, Arc<Mutex<()>>>>>,
    database: PgPool,
    storage: PathBuf,
    shutdown: CancellationToken,
    segment_seconds: u64,
}

impl CameraManager {
    pub fn new(
        database: PgPool,
        storage: PathBuf,
        shutdown: CancellationToken,
        segment_seconds: u64,
    ) -> Self {
        Self {
            workers: Arc::new(Mutex::new(HashMap::new())),
            lifecycle_locks: Arc::new(Mutex::new(HashMap::new())),
            database,
            storage,
            shutdown,
            segment_seconds,
        }
    }

    async fn lifecycle_lock(&self, id: &str) -> Arc<Mutex<()>> {
        let mut locks = self.lifecycle_locks.lock().await;
        locks
            .entry(id.to_string())
            .or_insert_with(|| Arc::new(Mutex::new(())))
            .clone()
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

    pub async fn reconcile(&self) -> Result<(), sqlx::Error> {
        let enabled = sqlx::query_scalar::<_, String>("SELECT id FROM cameras WHERE enabled")
            .fetch_all(&self.database)
            .await?;
        let running: Vec<String> = self.workers.lock().await.keys().cloned().collect();
        for id in &enabled {
            if let Err(error) = self.start(id).await {
                tracing::warn!(camera_id=%id, %error, "camera reconciliation start deferred");
            }
        }
        for id in running {
            if !enabled.contains(&id) {
                let _ = self.stop(&id).await;
            }
        }
        Ok(())
    }

    pub async fn start(&self, id: &str) -> Result<CameraState, String> {
        let lifecycle_lock = self.lifecycle_lock(id).await;
        let _lifecycle_guard = lifecycle_lock.lock().await;

        if let Some(handle) = self.workers.lock().await.get(id)
            && !handle.task.is_finished()
        {
            return Ok(*handle.status.borrow());
        }

        self.workers.lock().await.remove(id);
        let camera = sqlx::query_as::<_, CameraConfig>(
            r#"
            SELECT
                c.id,
                c.host,
                c.port,
                c.username,
                c.password_secret,
                c.main_stream,
                c.sub_stream,
                COALESCE(rc.enabled, false) AS recording_enabled,
                rc.retention_days
            FROM cameras c
            LEFT JOIN recording_configs rc ON rc.camera_id = c.id
            WHERE c.id = $1 AND c.enabled
            "#,
        )
        .bind(id)
        .fetch_optional(&self.database)
        .await
        .map_err(|error| error.to_string())?
        .ok_or_else(|| "enabled camera not found".to_string())?;

        let (tx, rx) = mpsc::channel(8);
        let (status_tx, status_rx) = watch::channel(CameraState::Starting);
        let worker = CameraWorker::new(
            camera,
            self.database.clone(),
            self.storage.clone(),
            rx,
            status_tx,
            self.shutdown.child_token(),
            self.segment_seconds,
        );
        let task = tokio::spawn(async move {
            worker.run().await;
        });
        self.workers.lock().await.insert(
            id.to_string(),
            WorkerHandle {
                commands: tx,
                status: status_rx,
                task,
            },
        );
        Ok(CameraState::Starting)
    }

    pub async fn stop(&self, id: &str) -> Result<CameraState, String> {
        let lifecycle_lock = self.lifecycle_lock(id).await;
        let _lifecycle_guard = lifecycle_lock.lock().await;

        let Some(handle) = self.workers.lock().await.remove(id) else {
            return Ok(CameraState::Disabled);
        };
        handle
            .commands
            .send(CameraCommand::Stop)
            .await
            .map_err(|_| "camera worker stopped".to_string())?;
        let _ = tokio::time::timeout(std::time::Duration::from_secs(10), handle.task).await;
        Ok(CameraState::Disabled)
    }

    pub async fn status(&self, id: &str) -> CameraState {
        let workers = self.workers.lock().await;
        workers
            .get(id)
            .filter(|handle| !handle.task.is_finished())
            .map(|handle| *handle.status.borrow())
            .unwrap_or(CameraState::Disabled)
    }

    pub async fn probe_status(&self, id: &str) -> Result<CameraState, String> {
        let sender = {
            let workers = self.workers.lock().await;
            workers
                .get(id)
                .map(|handle| handle.commands.clone())
                .ok_or_else(|| "camera worker not found".to_string())?
        };
        let (tx, rx) = oneshot::channel();
        sender
            .send(CameraCommand::Status(tx))
            .await
            .map_err(|_| "camera worker stopped".to_string())?;
        rx.await.map_err(|_| "camera worker stopped".to_string())
    }

    pub async fn readiness(&self) -> Result<(), String> {
        sqlx::query("SELECT 1")
            .execute(&self.database)
            .await
            .map_err(|error| error.to_string())?;
        tokio::fs::create_dir_all(&self.storage)
            .await
            .map_err(|error| error.to_string())?;
        let probe = self.storage.join(".aegivue-write-probe");
        tokio::fs::write(&probe, b"ready")
            .await
            .map_err(|error| error.to_string())?;
        tokio::fs::remove_file(probe)
            .await
            .map_err(|error| error.to_string())?;
        Ok(())
    }

    pub async fn shutdown_workers(&self) {
        let handles: Vec<_> = self
            .workers
            .lock()
            .await
            .drain()
            .map(|(_, handle)| handle)
            .collect();
        for handle in &handles {
            let _ = handle.commands.send(CameraCommand::Stop).await;
        }
        for handle in handles {
            let _ = tokio::time::timeout(std::time::Duration::from_secs(10), handle.task).await;
        }
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
                task: tokio::spawn(async {}),
            },
        );
        guard.insert(
            "two".into(),
            WorkerHandle {
                commands: tx2,
                status: rx2,
                task: tokio::spawn(async {}),
            },
        );
        guard.remove("one");
        assert!(guard.contains_key("two"));
    }

    #[tokio::test]
    async fn per_camera_lifecycle_lock_is_shared_only_by_same_camera() {
        let locks: Arc<Mutex<HashMap<String, Arc<Mutex<()>>>>> =
            Arc::new(Mutex::new(HashMap::new()));
        let one = {
            let mut guard = locks.lock().await;
            guard
                .entry("one".into())
                .or_insert_with(|| Arc::new(Mutex::new(())))
                .clone()
        };
        let one_again = {
            let mut guard = locks.lock().await;
            guard
                .entry("one".into())
                .or_insert_with(|| Arc::new(Mutex::new(())))
                .clone()
        };
        let two = {
            let mut guard = locks.lock().await;
            guard
                .entry("two".into())
                .or_insert_with(|| Arc::new(Mutex::new(())))
                .clone()
        };

        assert!(Arc::ptr_eq(&one, &one_again));
        assert!(!Arc::ptr_eq(&one, &two));
    }
}
