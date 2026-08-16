use chrono::{DateTime, Local};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CameraState {
    Disabled,
    Starting,
    Connecting,
    Online,
    Degraded,
    Reconnecting,
    Offline,
    Stopping,
    Error,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CameraStatus {
    pub camera_id: String,
    pub state: CameraState,
    pub changed_at: DateTime<Local>,
    pub reason: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CameraControlResponse {
    pub camera_id: String,
    pub state: CameraState,
}
