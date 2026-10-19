import 'package:aegivue/core/utils/formatters.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_playback.dart';
import 'package:aegivue/features/recordings/presentation/recording_download.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_player.dart';
import 'package:flutter/material.dart';

class SelectedRecordingCard extends StatelessWidget {
  const SelectedRecordingCard({
    super.key,
    required this.recording,
    this.cameraName,
    this.onSetExpiry,
    required this.onClose,
    required this.updatingExpiry,
    this.playerController,
    this.initialPosition = Duration.zero,
    this.onPlaybackEvent,
    this.playbackControls,
    this.subtitle,
    this.autoplay = false,
  });

  final Recording recording;
  final String? cameraName;
  final VoidCallback? onSetExpiry;
  final VoidCallback onClose;
  final bool updatingExpiry;
  final RecordingPlayerController? playerController;
  final Duration initialPosition;
  final ValueChanged<RecordingPlaybackEvent>? onPlaybackEvent;
  final Widget? playbackControls;
  final String? subtitle;
  final bool autoplay;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SelectedRecordingHeader(
            recording: recording,
            cameraName: cameraName,
            onSetExpiry: onSetExpiry,
            onClose: onClose,
            updatingExpiry: updatingExpiry,
            playbackControls: playbackControls,
            subtitle: subtitle,
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: RecordingPlayer(
              playbackUrl: recording.playbackUrl,
              controller: playerController,
              initialPosition: initialPosition,
              onPlaybackEvent: onPlaybackEvent,
              autoplay: autoplay,
            ),
          ),
          _RecordingDetails(recording: recording),
        ],
      ),
    );
  }
}

class _SelectedRecordingHeader extends StatelessWidget {
  const _SelectedRecordingHeader({
    required this.recording,
    required this.cameraName,
    required this.onSetExpiry,
    required this.onClose,
    required this.updatingExpiry,
    required this.playbackControls,
    required this.subtitle,
  });

  final Recording recording;
  final String? cameraName;
  final VoidCallback? onSetExpiry;
  final VoidCallback onClose;
  final bool updatingExpiry;
  final Widget? playbackControls;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (playbackControls != null && constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.play_circle_fill_rounded, size: 20),
                    const SizedBox(width: 9),
                    Expanded(child: _title()),
                    _closeButton(),
                  ],
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    playbackControls!,
                    _expiryButton(),
                    _downloadButton(),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              const Icon(Icons.play_circle_fill_rounded, size: 20),
              const SizedBox(width: 9),
              Expanded(child: _title()),
              ?playbackControls,
              _expiryButton(),
              _downloadButton(),
              _closeButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _title() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        cameraName ?? recording.cameraId,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      Text(
        subtitle ?? Formatters.recordingTimestamp(recording.startTime),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
    ],
  );

  Widget _expiryButton() => _ExpiryButton(
    recording: recording,
    onSetExpiry: onSetExpiry,
    updating: updatingExpiry,
  );

  Widget _downloadButton() => IconButton(
    tooltip: 'Download recording',
    onPressed: () => RecordingDownload.start(recording),
    icon: const Icon(Icons.download_rounded),
  );

  Widget _closeButton() => IconButton(
    tooltip: 'Close player',
    onPressed: onClose,
    icon: const Icon(Icons.close_rounded),
  );
}

class _ExpiryButton extends StatelessWidget {
  const _ExpiryButton({
    required this.recording,
    required this.onSetExpiry,
    required this.updating,
  });

  final Recording recording;
  final VoidCallback? onSetExpiry;
  final bool updating;

  @override
  Widget build(BuildContext context) {
    final callback = onSetExpiry;
    if (callback == null) return const SizedBox.shrink();

    return IconButton(
      tooltip: _expiryTooltip(recording),
      onPressed: _enabledCallback(callback),
      icon: _icon(),
    );
  }

  VoidCallback? _enabledCallback(VoidCallback callback) {
    if (updating) return null;
    if (recording.protected) return null;
    return callback;
  }

  Widget _icon() {
    if (updating) {
      return const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (recording.expiresAt == null) {
      return const Icon(Icons.event_available_outlined);
    }
    return const Icon(Icons.event_busy_outlined);
  }
}

class _RecordingDetails extends StatelessWidget {
  const _RecordingDetails({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        children: [
          _Detail(label: 'Container', value: recording.container.toUpperCase()),
          _Detail(
            label: 'Start',
            value: Formatters.recordingTimestamp(recording.startTime),
          ),
          ..._optionalDetail(
            'End',
            recording.endTime == null
                ? null
                : Formatters.recordingTimestamp(recording.endTime!),
          ),
          ..._optionalDetail('Duration', _duration(recording)),
          ..._optionalDetail('Video', recording.videoCodec),
          ..._optionalDetail('Audio', recording.audioCodec),
          ..._optionalDetail('Resolution', _resolution(recording)),
          ..._optionalDetail('FPS', recording.fps?.toStringAsFixed(1)),
          _Detail(label: 'Retention', value: _retention(recording.expiresAt)),
          ..._protectionDetails(recording.protected),
        ],
      ),
    );
  }
}

List<Widget> _optionalDetail(String label, String? value) {
  if (value == null) return const [];
  return [_Detail(label: label, value: value)];
}

List<Widget> _protectionDetails(bool protected) {
  if (!protected) return const [];
  return const [_Detail(label: 'Protection', value: 'Protected')];
}

String? _resolution(Recording recording) {
  final width = recording.width;
  final height = recording.height;
  if (width == null || height == null) return null;
  return '$width×$height';
}

String? _duration(Recording recording) {
  final milliseconds =
      recording.durationMs ??
      recording.endTime?.difference(recording.startTime).inMilliseconds;
  if (milliseconds == null) return null;
  final duration = Duration(milliseconds: milliseconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
  return '${minutes}m ${seconds}s';
}

String _retention(DateTime? expiresAt) {
  if (expiresAt == null) return 'Keep indefinitely';
  return 'Expires ${_formatExpiry(expiresAt)}';
}

String _expiryTooltip(Recording recording) {
  if (recording.protected) return 'Protected recordings cannot expire';
  if (recording.expiresAt == null) return 'Set expiry date';
  return 'Change expiry date';
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 11, color: Colors.white54),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatExpiry(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
