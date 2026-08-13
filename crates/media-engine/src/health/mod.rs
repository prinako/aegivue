use crate::camera::CameraManager;
use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
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
        .route("/internal/v1/cameras/{id}/start", post(start))
        .route("/internal/v1/cameras/{id}/stop", post(stop))
        .route("/internal/v1/cameras/{id}/status", get(status))
        .with_state(manager)
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
}
