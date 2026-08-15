use aegivue_common::CameraState;
use tokio::sync::oneshot;

#[derive(Debug)]
pub enum CameraCommand {
    Stop,
    Status(oneshot::Sender<CameraState>),
}
