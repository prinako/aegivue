enum RecordingPlaybackPhase {
  idle,
  loading,
  ready,
  playing,
  paused,
  ended,
  error,
}

class RecordingPlaybackEvent {
  const RecordingPlaybackEvent({
    required this.phase,
    this.position = Duration.zero,
    this.duration,
    this.error,
  });

  final RecordingPlaybackPhase phase;
  final Duration position;
  final Duration? duration;
  final String? error;
}

class RecordingPlaybackSnapshot {
  const RecordingPlaybackSnapshot({
    this.phase = RecordingPlaybackPhase.idle,
    this.position = Duration.zero,
    this.duration,
    this.error,
  });

  final RecordingPlaybackPhase phase;
  final Duration position;
  final Duration? duration;
  final String? error;

  bool get playing => phase == RecordingPlaybackPhase.playing;
  bool get loading => phase == RecordingPlaybackPhase.loading;
}
