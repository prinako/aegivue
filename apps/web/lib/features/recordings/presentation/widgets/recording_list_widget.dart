import 'package:aegivue/core/utils/formatters.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/recording_download.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_player.dart';
import 'package:flutter/material.dart';

class RecordingListWidget extends StatelessWidget {
  const RecordingListWidget({
    super.key,
    required this.recordings,
    required this.onOpen,
    this.selectedId,
  });

  final List<Recording> recordings;
  final ValueChanged<Recording> onOpen;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    if (recordings.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(Icons.video_library_outlined, color: Colors.white38),
              SizedBox(width: 12),
              Text(
                'No finalized recordings yet.',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 4
            : constraints.maxWidth >= 850
            ? 3
            : constraints.maxWidth >= 540
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final recording in recordings)
              SizedBox(
                width: width,
                child: _RecordingCard(
                  recording: recording,
                  selected: recording.id == selectedId,
                  onTap: () => onOpen(recording),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({
    required this.recording,
    required this.selected,
    required this.onTap,
  });

  final Recording recording;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = _duration(recording.durationMs);
    final resolution = recording.width != null && recording.height != null
        ? '${recording.width}×${recording.height}'
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RecordingPlayer(
                    playbackUrl: recording.playbackUrl,
                    thumbnail: true,
                  ),
                  Positioned(
                    right: 10,
                    bottom: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recording.cameraId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Download recording',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => RecordingDownload.start(recording),
                        icon: const Icon(Icons.download_rounded, size: 19),
                      ),
                      const Icon(Icons.play_circle_outline_rounded, size: 19),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    Formatters.recordingTimestamp(recording.startTime),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MetaChip(recording.container.toUpperCase()),
                      if (resolution != null) _MetaChip(resolution),
                      if (recording.fileSize != null)
                        _MetaChip(_fileSize(recording.fileSize!)),
                      _MetaChip(
                        recording.protected
                            ? 'Protected'
                            : recording.expiresAt == null
                            ? 'Keep indefinitely'
                            : 'Expires ${_expiry(recording.expiresAt!)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _duration(int? milliseconds) {
    if (milliseconds == null || milliseconds <= 0) return '--:--';
    final totalSeconds = (milliseconds / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String _fileSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  static String _expiry(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white54, fontSize: 9),
      ),
    );
  }
}
