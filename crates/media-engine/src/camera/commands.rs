use tokio::sync::oneshot;
use vigilo_common::CameraState;

#[derive(Debug)]
pub enum CameraCommand {
    Stop,
    Status(oneshot::Sender<CameraState>),
}
