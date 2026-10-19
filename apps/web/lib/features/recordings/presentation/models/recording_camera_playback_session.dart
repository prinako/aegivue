import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/domain/recording_timeline_interval.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_playback.dart';

enum RecordingCameraSessionPhase { noFootage, loading, ready, error }

class RecordingCameraPlaybackSession {
  const RecordingCameraPlaybackSession({
    required this.cameraId,
    required this.timestamp,
    required this.phase,
    this.interval,
    this.recording,
    this.playback = const RecordingPlaybackSnapshot(),
    this.error,
  });

  final String cameraId;
  final DateTime timestamp;
  final RecordingCameraSessionPhase phase;
  final RecordingTimelineInterval? interval;
  final Recording? recording;
  final RecordingPlaybackSnapshot playback;
  final String? error;

  bool get hasFootage => interval != null;

  Duration get offset {
    final value = interval;
    if (value == null) return Duration.zero;
    final result = timestamp.difference(value.startTime);
    if (result.isNegative) return Duration.zero;
    return result > value.duration ? value.duration : result;
  }

  RecordingCameraPlaybackSession copyWith({
    DateTime? timestamp,
    RecordingCameraSessionPhase? phase,
    Recording? recording,
    RecordingPlaybackSnapshot? playback,
    String? error,
  }) => RecordingCameraPlaybackSession(
    cameraId: cameraId,
    timestamp: timestamp ?? this.timestamp,
    phase: phase ?? this.phase,
    interval: interval,
    recording: recording ?? this.recording,
    playback: playback ?? this.playback,
    error: error ?? this.error,
  );
}
