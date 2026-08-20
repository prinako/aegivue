use sqlx::PgPool;
use std::path::{Path, PathBuf};
use tokio_util::sync::CancellationToken;

pub async fn supervise(
    database: PgPool,
    storage: PathBuf,
    shutdown: CancellationToken,
) {
    let mut interval = tokio::time::interval(std::time::Duration::from_secs(300));
    loop {
        tokio::select! {
            _ = interval.tick() => {
                if let Err(error) = purge_expired(&database, &storage).await {
                    tracing::error!(%error, "recording retention cleanup failed");
                }
            }
            () = shutdown.cancelled() => break,
        }
    }
}

async fn purge_expired(database: &PgPool, storage: &Path) -> Result<(), sqlx::Error> {
    let rows = sqlx::query_as::<_, (uuid::Uuid, String)>(
        r#"
        SELECT id, file_path
        FROM recordings
        WHERE expires_at IS NOT NULL
          AND expires_at <= now()
          AND protected = false
        ORDER BY expires_at
        LIMIT 100
        "#,
    )
    .fetch_all(database)
    .await?;

    for (id, file_path) in rows {
        let Some(path) = safe_recording_path(storage, &file_path) else {
            tracing::error!(recording_id=%id, %file_path, "refusing to delete recording outside storage root");
            continue;
        };

        match tokio::fs::remove_file(&path).await {
            Ok(()) => {}
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                tracing::warn!(recording_id=%id, path=%path.display(), "expired recording file was already missing");
            }
            Err(error) => {
                tracing::warn!(recording_id=%id, path=%path.display(), %error, "unable to delete expired recording file");
                continue;
            }
        }

        sqlx::query("DELETE FROM recordings WHERE id=$1 AND protected=false AND expires_at <= now()")
            .bind(id)
            .execute(database)
            .await?;
        tracing::info!(recording_id=%id, path=%path.display(), "expired recording deleted");
    }

    Ok(())
}

fn safe_recording_path(storage: &Path, file_path: &str) -> Option<PathBuf> {
    let relative = Path::new(file_path);
    if relative.is_absolute() || relative.components().any(|component| {
        matches!(component, std::path::Component::ParentDir)
    }) {
        return None;
    }
    Some(storage.join(relative))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn recording_path_rejects_parent_traversal() {
        let root = Path::new("/data/recordings");
        assert!(safe_recording_path(root, "cam/2026/08/clip.mp4").is_some());
        assert!(safe_recording_path(root, "../outside.mp4").is_none());
        assert!(safe_recording_path(root, "/etc/passwd").is_none());
    }
}
