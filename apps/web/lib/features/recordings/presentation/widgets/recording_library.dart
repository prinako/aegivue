import 'package:aegivue/core/utils/formatters.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/recording_download.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_list_widget.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_player.dart';
import 'package:flutter/material.dart';

class RecordingLibrary extends StatefulWidget {
  const RecordingLibrary({
    super.key,
    required this.recordings,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onSetExpiry,
    required this.hasMore,
    required this.loadingMore,
  });

  final List<Recording> recordings;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Future<void> Function(Recording recording, DateTime? expiresAt)
  onSetExpiry;
  final bool hasMore;
  final bool loadingMore;

  @override
  State<RecordingLibrary> createState() => _RecordingLibraryState();
}

class _RecordingLibraryState extends State<RecordingLibrary> {
  final ScrollController _scrollController = ScrollController();
  Recording? selected;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RecordingLibrary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (selected == null) return;
    final matches = widget.recordings.where((item) => item.id == selected!.id);
    selected = matches.isEmpty ? null : matches.first;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        widget.loadingMore ||
        !widget.hasMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.extentAfter <= 600) {
      widget.onLoadMore();
    }
  }

  Future<void> _setExpiry(Recording recording) async {
    if (recording.protected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Protected recordings cannot expire.')),
      );
      return;
    }

    final action = await showModalBottomSheet<_ExpiryAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Recording expiry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                recording.expiresAt == null
                    ? 'This recording is currently kept indefinitely.'
                    : 'Current expiry: ${_formatExpiry(recording.expiresAt!)}',
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop(_ExpiryAction.pick),
                icon: const Icon(Icons.event_rounded),
                label: const Text('Choose expiry date'),
              ),
              if (recording.expiresAt != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(_ExpiryAction.clear),
                  icon: const Icon(Icons.all_inclusive_rounded),
                  label: const Text('Keep indefinitely'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    DateTime? expiresAt;
    if (action == _ExpiryAction.pick) {
      final now = DateTime.now();
      final initial = recording.expiresAt?.toLocal();
      final date = await showDatePicker(
        context: context,
        initialDate: initial != null && initial.isAfter(now)
            ? initial
            : now.add(const Duration(days: 7)),
        firstDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
        lastDate: DateTime(now.year + 10, 12, 31),
        helpText: 'Delete recording after',
      );
      if (date == null) return;
      expiresAt = DateTime(date.year, date.month, date.day, 23, 59, 59);
    }

    try {
      await widget.onSetExpiry(recording, expiresAt);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            expiresAt == null
                ? 'Recording will now be kept indefinitely.'
                : 'Recording will expire after ${_formatExpiry(expiresAt)}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update expiry: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 44),
        children: [
          Text(
            'Recording library',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Browse, preview, download, and control how long finalized footage is retained.',
            style: TextStyle(color: Colors.white54),
          ),
          if (selected != null) ...[
            const SizedBox(height: 20),
            _SelectedRecording(
              recording: selected!,
              onSetExpiry: () => _setExpiry(selected!),
              onClose: () => setState(() => selected = null),
            ),
          ],
          const SizedBox(height: 20),
          RecordingListWidget(
            recordings: widget.recordings,
            selectedId: selected?.id,
            onOpen: (recording) => setState(() => selected = recording),
          ),
          if (widget.loadingMore) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ] else if (!widget.hasMore && widget.recordings.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'All recordings loaded',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedRecording extends StatelessWidget {
  const _SelectedRecording({
    required this.recording,
    required this.onSetExpiry,
    required this.onClose,
  });

  final Recording recording;
  final VoidCallback onSetExpiry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
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
                IconButton(
                  tooltip: recording.expiresAt == null
                      ? 'Set expiry date'
                      : 'Change expiry date',
                  onPressed: onSetExpiry,
                  icon: Icon(
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

enum _ExpiryAction { pick, clear }

String _formatExpiry(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
