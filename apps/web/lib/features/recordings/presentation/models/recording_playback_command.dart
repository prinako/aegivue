enum RecordingPlaybackCommandType { play, pause, seek }

class RecordingPlaybackCommand {
  const RecordingPlaybackCommand({
    required this.type,
    this.cameraId,
    this.position,
  });

  final RecordingPlaybackCommandType type;
  final String? cameraId;
  final Duration? position;
}
