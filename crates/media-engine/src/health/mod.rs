use crate::{camera::CameraManager, live};
use axum::{
    Json, Router,
    body::Body,
    extract::{Path, State},
    http::{Response, StatusCode, header},
    routing::{get, post},
};
use serde::Serialize;
use vigilo_common::CameraControlResponse;

#[derive(Serialize)]
struct Health {
    status: &'static str,
    service: &'static str,
}

pub fn router(manager: CameraManager) -> Router {
    Router::new()
        .route(
            "/internal/v1/health",
            get(|| async {
                Json(Health {
                    status: "ok",
                    service: "vigilo-media",
                })
            }),
        )
        .route(
            "/internal/v1/live",
            get(|| async {
                Json(Health {
                    status: "ok",
                    service: "vigilo-media",
                })
            }),
        )
        .route("/internal/v1/ready", get(readiness))
        .route("/internal/v1/cameras/{id}/start", post(start))
        .route("/internal/v1/cameras/{id}/stop", post(stop))
        .route("/internal/v1/cameras/{id}/status", get(status))
        .route("/live/{camera}/{file}", get(live_asset))
        .with_state(manager)
}

async fn readiness(
    State(manager): State<CameraManager>,
) -> Result<Json<Health>, (StatusCode, String)> {
    manager
        .readiness()
        .await
        .map(|()| {
            Json(Health {
                status: "ready",
                service: "vigilo-media",
            })
        })
        .map_err(|error| (StatusCode::SERVICE_UNAVAILABLE, error))
}

async fn start(
    State(m): State<CameraManager>,
    Path(id): Path<String>,
) -> Result<Json<CameraControlResponse>, (StatusCode, String)> {
    m.start(&id)
        .await
        .map(|state| {
            Json(CameraControlResponse {
                camera_id: id,
                state,
            })
        })
        .map_err(|e| (StatusCode::NOT_FOUND, e))
}

async fn stop(
    State(m): State<CameraManager>,
    Path(id): Path<String>,
) -> Result<Json<CameraControlResponse>, (StatusCode, String)> {
    m.stop(&id)
        .await
        .map(|state| {
            Json(CameraControlResponse {
                camera_id: id,
                state,
            })
        })
        .map_err(|e| (StatusCode::NOT_FOUND, e))
}

async fn status(
    State(m): State<CameraManager>,
    Path(id): Path<String>,
) -> Json<CameraControlResponse> {
    Json(CameraControlResponse {
        camera_id: id.clone(),
        state: m.status(&id).await,
    })
}

async fn live_asset(
    Path((camera, file)): Path<(String, String)>,
) -> Result<Response<Body>, StatusCode> {
    if !safe_component(&camera) || !safe_live_file(&file) {
        return Err(StatusCode::BAD_REQUEST);
    }

    let path = live::root().join(camera).join(&file);
    let bytes = tokio::fs::read(path).await.map_err(|error| match error.kind() {
        std::io::ErrorKind::NotFound => StatusCode::NOT_FOUND,
        _ => StatusCode::INTERNAL_SERVER_ERROR,
    })?;

    let content_type = if file.ends_with(".m3u8") {
        "application/vnd.apple.mpegurl"
    } else {
        "video/mp2t"
    };

    Response::builder()
        .status(StatusCode::OK)
        .header(header::CONTENT_TYPE, content_type)
        .header(header::CACHE_CONTROL, "no-store, no-cache, must-revalidate")
        .header("Access-Control-Allow-Origin", "*")
        .body(Body::from(bytes))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

fn safe_component(value: &str) -> bool {
    !value.is_empty()
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_'))
}

fn safe_live_file(value: &str) -> bool {
    value == "index.m3u8"
        || (value.starts_with("segment-")
            && value.ends_with(".ts")
            && value[8..value.len() - 3]
                .bytes()
                .all(|byte| byte.is_ascii_digit()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use vigilo_common::CameraState;

    #[test]
    fn control_contract_serializes() {
        let json = serde_json::to_string(&CameraControlResponse {
            camera_id: "cam_one".into(),
            state: CameraState::Online,
        })
        .unwrap();
        assert_eq!(json, r#"{"camera_id":"cam_one","state":"online"}"#);
    }

    #[test]
    fn live_paths_are_restricted() {
        assert!(safe_component("front-door_1"));
        assert!(!safe_component("../secret"));
        assert!(safe_live_file("index.m3u8"));
        assert!(safe_live_file("segment-000001.ts"));
        assert!(!safe_live_file("../../etc/passwd"));
    }
}
