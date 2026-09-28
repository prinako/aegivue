import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_expiry_sheet.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_list_widget.dart';
import 'package:aegivue/features/recordings/presentation/widgets/selected_recording_card.dart';
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
    required this.updatingExpiry,
  });

  final List<Recording> recordings;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Future<void> Function(Recording recording, DateTime? expiresAt)
  onSetExpiry;
  final bool hasMore;
  final bool loadingMore;
  final bool updatingExpiry;

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
    if (widget.updatingExpiry) return;
    if (recording.protected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Protected recordings cannot expire.')),
      );
      return;
    }

    final action = await showModalBottomSheet<_ExpiryAction>(
      context: context,
      builder: (sheetContext) => RecordingExpirySheet(
        recording: recording,
        onPick: () => Navigator.of(sheetContext).pop(_ExpiryAction.pick),
        onClear: () => Navigator.of(sheetContext).pop(_ExpiryAction.clear),
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
        firstDate: DateTime(
          now.year,
          now.month,
          now.day,
        ).add(const Duration(days: 1)),
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
            SelectedRecordingCard(
              recording: selected!,
              onSetExpiry: () => _setExpiry(selected!),
              onClose: () => setState(() => selected = null),
              updatingExpiry: widget.updatingExpiry,
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

enum _ExpiryAction { pick, clear }

String _formatExpiry(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
