import 'package:aegivue/core/utils/formatters.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/recording_download.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_player.dart';
import 'package:flutter/material.dart';

class SelectedRecordingCard extends StatelessWidget {
  const SelectedRecordingCard({
    super.key,
    required this.recording,
    this.onSetExpiry,
    required this.onClose,
    required this.updatingExpiry,
  });

  final Recording recording;
  final VoidCallback? onSetExpiry;
  final VoidCallback onClose;
  final bool updatingExpiry;

  @override
  Widget build(BuildContext context) {
    final expiryEnabled =
        onSetExpiry != null && !updatingExpiry && !recording.protected;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill_rounded, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recording.cameraId,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        Formatters.recordingTimestamp(recording.startTime),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onSetExpiry != null)
                  IconButton(
                    tooltip: _expiryTooltip(recording),
                    onPressed: expiryEnabled ? onSetExpiry : null,
                    icon: updatingExpiry
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            recording.expiresAt == null
                                ? Icons.event_available_outlined
                                : Icons.event_busy_outlined,
                          ),
                  ),
                IconButton(
                  tooltip: 'Download recording',
                  onPressed: () => RecordingDownload.start(recording),
                  icon: const Icon(Icons.download_rounded),
                ),
                IconButton(
                  tooltip: 'Close player',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: RecordingPlayer(playbackUrl: recording.playbackUrl),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _Detail(
                  label: 'Container',
                  value: recording.container.toUpperCase(),
                ),
                if (recording.videoCodec != null)
                  _Detail(label: 'Video', value: recording.videoCodec!),
                if (recording.audioCodec != null)
                  _Detail(label: 'Audio', value: recording.audioCodec!),
                if (recording.width != null && recording.height != null)
                  _Detail(
                    label: 'Resolution',
                    value: '${recording.width}×${recording.height}',
                  ),
                if (recording.fps != null)
                  _Detail(
                    label: 'FPS',
                    value: recording.fps!.toStringAsFixed(1),
                  ),
                _Detail(
                  label: 'Retention',
                  value: recording.expiresAt == null
                      ? 'Keep indefinitely'
                      : 'Expires ${_formatExpiry(recording.expiresAt!)}',
                ),
                if (recording.protected)
                  const _Detail(label: 'Protection', value: 'Protected'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _expiryTooltip(Recording recording) {
  if (recording.protected) return 'Protected recordings cannot expire';
  return recording.expiresAt == null ? 'Set expiry date' : 'Change expiry date';
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
