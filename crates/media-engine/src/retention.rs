use sqlx::PgPool;
use std::path::{Path, PathBuf};
use tokio_util::sync::CancellationToken;

pub async fn supervise(database: PgPool, storage: PathBuf, shutdown: CancellationToken) {
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
    let ids = sqlx::query_scalar::<_, uuid::Uuid>(
        r#"
        SELECT id
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

    for id in ids {
        let mut transaction = database.begin().await?;
        let candidate = sqlx::query_scalar::<_, String>(
            r#"
            SELECT file_path
            FROM recordings
            WHERE id=$1
              AND expires_at IS NOT NULL
              AND expires_at <= now()
              AND protected = false
            FOR UPDATE
            "#,
        )
        .bind(id)
        .fetch_optional(&mut *transaction)
        .await?;
        let Some(file_path) = candidate else {
            transaction.rollback().await?;
            continue;
        };
        let Some(path) = safe_recording_path(storage, &file_path) else {
            tracing::error!(recording_id=%id, %file_path, "refusing to delete recording outside storage root");
            transaction.rollback().await?;
            continue;
        };

        match tokio::fs::remove_file(&path).await {
            Ok(()) => {}
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                tracing::warn!(recording_id=%id, path=%path.display(), "expired recording file was already missing");
            }
            Err(error) => {
                tracing::warn!(recording_id=%id, path=%path.display(), %error, "unable to delete expired recording file");
                transaction.rollback().await?;
                continue;
            }
        }

        sqlx::query("DELETE FROM recordings WHERE id=$1")
            .bind(id)
            .execute(&mut *transaction)
            .await?;
        transaction.commit().await?;
        tracing::info!(recording_id=%id, path=%path.display(), "expired recording deleted");
    }

    Ok(())
}

fn safe_recording_path(storage: &Path, file_path: &str) -> Option<PathBuf> {
    let relative = Path::new(file_path);
    if relative.is_absolute()
        || relative
            .components()
            .any(|component| matches!(component, std::path::Component::ParentDir))
    {
        return None;
    }
    Some(storage.join(relative))
}

#[cfg(test)]
mod tests {
    use super::*;
    use sqlx::postgres::PgPoolOptions;
    use std::time::Duration;

    #[test]
    fn recording_path_rejects_parent_traversal() {
        let root = Path::new("/data/recordings");
        assert!(safe_recording_path(root, "cam/2026/08/clip.mp4").is_some());
        assert!(safe_recording_path(root, "../outside.mp4").is_none());
        assert!(safe_recording_path(root, "/etc/passwd").is_none());
    }

    #[tokio::test]
    #[ignore = "requires AEGIVUE_TEST_DATABASE_URL"]
    async fn protection_update_wins_before_retention_deletes_file() {
        let database_url = std::env::var("AEGIVUE_TEST_DATABASE_URL").unwrap();
        let database = PgPoolOptions::new()
            .max_connections(4)
            .connect(&database_url)
            .await
            .unwrap();
        sqlx::query("DROP TABLE IF EXISTS recordings")
            .execute(&database)
            .await
            .unwrap();
        sqlx::query(
            "CREATE TABLE recordings(id uuid PRIMARY KEY, file_path text NOT NULL, expires_at timestamptz, protected boolean NOT NULL DEFAULT false)",
        )
        .execute(&database)
        .await
        .unwrap();

        let root = std::env::temp_dir().join(format!("aegivue-retention-{}", uuid::Uuid::new_v4()));
        let relative = "front-door/expired.mp4";
        let recording = root.join(relative);
        tokio::fs::create_dir_all(recording.parent().unwrap())
            .await
            .unwrap();
        tokio::fs::write(&recording, b"protected footage")
            .await
            .unwrap();
        let id = uuid::Uuid::new_v4();
        sqlx::query(
            "INSERT INTO recordings(id,file_path,expires_at,protected) VALUES($1,$2,now()-interval '1 hour',false)",
        )
        .bind(id)
        .bind(relative)
        .execute(&database)
        .await
        .unwrap();

        let mut protection = database.begin().await.unwrap();
        sqlx::query("UPDATE recordings SET protected=true WHERE id=$1")
            .bind(id)
            .execute(&mut *protection)
            .await
            .unwrap();

        let cleanup = tokio::spawn({
            let database = database.clone();
            let root = root.clone();
            async move { purge_expired(&database, &root).await }
        });
        tokio::time::sleep(Duration::from_millis(100)).await;
        assert!(tokio::fs::try_exists(&recording).await.unwrap());

        protection.commit().await.unwrap();
        cleanup.await.unwrap().unwrap();
        assert!(tokio::fs::try_exists(&recording).await.unwrap());
        let protected: bool = sqlx::query_scalar("SELECT protected FROM recordings WHERE id=$1")
            .bind(id)
            .fetch_one(&database)
            .await
            .unwrap();
        assert!(protected);

        tokio::fs::remove_dir_all(root).await.unwrap();
        sqlx::query("DROP TABLE recordings")
            .execute(&database)
            .await
            .unwrap();
    }
}
