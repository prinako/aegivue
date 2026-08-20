use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MotionRecordingSignal {
    Started(Uuid),
    Ended(Uuid),
}
