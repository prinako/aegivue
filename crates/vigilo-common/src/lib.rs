use chrono::{DateTime, Utc};
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
    pub changed_at: DateTime<Utc>,
    pub reason: Option<String>,
}
