use aegivue_media::recording::catalog::{RecordingCatalog, RecordingMetadata};
use chrono::{TimeZone, Utc};
use sqlx::postgres::PgPoolOptions;
use std::time::Duration;
use uuid::Uuid;

#[tokio::test]
async fn failed_database_insert_leaves_durable_metadata_for_retry() {
    let root = std::env::temp_dir().join(format!("aegivue-catalog-{}", Uuid::new_v4()));
    tokio::fs::create_dir_all(&root).await.unwrap();
    let id = Uuid::new_v4();
    let catalog = RecordingCatalog::new(
        PgPoolOptions::new()
            .acquire_timeout(Duration::from_millis(50))
            .connect_lazy("postgres://127.0.0.1:1/aegivue")
            .unwrap(),
        root.clone(),
    );
    let metadata = RecordingMetadata {
        id,
        camera_id: "front-door".into(),
        event_id: Some(Uuid::new_v4()),
        start_time: Utc.with_ymd_and_hms(2026, 9, 29, 10, 0, 0).unwrap(),
        end_time: Utc.with_ymd_and_hms(2026, 9, 29, 10, 1, 0).unwrap(),
        file_path: "front-door/2026/09/29/10/10-00-00.mp4".into(),
        file_size: 1024,
        duration_ms: 60_000,
        expires_at: None,
    };

    assert!(catalog.persist(&metadata).await.is_err());
    let pending = root.join(".metadata-pending").join(format!("{id}.json"));
    assert!(tokio::fs::try_exists(&pending).await.unwrap());

    let staged: RecordingMetadata =
        serde_json::from_slice(&tokio::fs::read(&pending).await.unwrap()).unwrap();
    assert_eq!(staged, metadata);

    tokio::fs::remove_dir_all(root).await.unwrap();
}

#[tokio::test]
#[ignore = "requires AEGIVUE_TEST_DATABASE_URL"]
async fn staged_metadata_is_recovered_after_database_returns() {
    let database_url = std::env::var("AEGIVUE_TEST_DATABASE_URL").unwrap();
    let database = PgPoolOptions::new()
        .max_connections(2)
        .connect(&database_url)
        .await
        .unwrap();
    sqlx::query("DROP TABLE IF EXISTS recordings")
        .execute(&database)
        .await
        .unwrap();
    sqlx::query(
        r#"
        CREATE TABLE recordings(
            id uuid PRIMARY KEY,
            camera_id text NOT NULL,
            event_id uuid,
            start_time timestamptz NOT NULL,
            end_time timestamptz,
            file_path text NOT NULL UNIQUE,
            file_size bigint,
            container text NOT NULL,
            duration_ms bigint,
            expires_at timestamptz
        )
        "#,
    )
    .execute(&database)
    .await
    .unwrap();

    let root = std::env::temp_dir().join(format!("aegivue-catalog-{}", Uuid::new_v4()));
    let relative = "front-door/2026/09/29/10/10-00-00.mp4";
    let recording = root.join(relative);
    tokio::fs::create_dir_all(recording.parent().unwrap())
        .await
        .unwrap();
    tokio::fs::write(&recording, b"recording").await.unwrap();
    let metadata = RecordingMetadata {
        id: Uuid::new_v4(),
        camera_id: "front-door".into(),
        event_id: Some(Uuid::new_v4()),
        start_time: Utc.with_ymd_and_hms(2026, 9, 29, 10, 0, 0).unwrap(),
        end_time: Utc.with_ymd_and_hms(2026, 9, 29, 10, 1, 0).unwrap(),
        file_path: relative.into(),
        file_size: 1024,
        duration_ms: 60_000,
        expires_at: None,
    };
    let unavailable = RecordingCatalog::new(
        PgPoolOptions::new()
            .acquire_timeout(Duration::from_millis(50))
            .connect_lazy("postgres://127.0.0.1:1/aegivue")
            .unwrap(),
        root.clone(),
    );
    assert!(unavailable.persist(&metadata).await.is_err());

    let catalog = RecordingCatalog::new(database.clone(), root.clone());
    assert_eq!(catalog.recover_pending().await.unwrap(), 1);
    let recovered: (Uuid, Option<Uuid>) =
        sqlx::query_as("SELECT id,event_id FROM recordings WHERE file_path=$1")
            .bind(relative)
            .fetch_one(&database)
            .await
            .unwrap();
    assert_eq!(recovered, (metadata.id, metadata.event_id));
    assert!(
        !tokio::fs::try_exists(
            root.join(".metadata-pending")
                .join(format!("{}.json", metadata.id))
        )
        .await
        .unwrap()
    );

    tokio::fs::remove_dir_all(root).await.unwrap();
    sqlx::query("DROP TABLE recordings")
        .execute(&database)
        .await
        .unwrap();
}
