class RecordingPlaybackCorrection {
  const RecordingPlaybackCorrection({
    required this.cameraId,
    required this.position,
  });

  final String cameraId;
  final Duration position;
}
