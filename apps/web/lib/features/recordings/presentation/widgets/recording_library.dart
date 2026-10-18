import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_details_dialog.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_date_filter_control.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_expiry_sheet.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_list_widget.dart';
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
    this.filterFrom,
    this.filterTo,
    this.onApplyDateFilter = _ignoreDateFilter,
    this.onClearDateFilter = _ignoreClearDateFilter,
  });

  final List<Recording> recordings;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Future<void> Function(Recording recording, DateTime? expiresAt)
  onSetExpiry;
  final bool hasMore;
  final bool loadingMore;
  final bool updatingExpiry;
  final DateTime? filterFrom;
  final DateTime? filterTo;
  final ApplyRecordingDateFilter onApplyDateFilter;
  final Future<void> Function() onClearDateFilter;

  bool get hasDateFilter => filterFrom != null || filterTo != null;

  @override
  State<RecordingLibrary> createState() => _RecordingLibraryState();
}

class _RecordingLibraryState extends State<RecordingLibrary> {
  final ScrollController _scrollController = ScrollController();

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

  Future<bool> _setExpiry(Recording recording) async {
    if (widget.updatingExpiry) return false;
    final selection = await _chooseExpiry(recording);
    if (!mounted || selection == null) return false;
    return _saveExpiry(recording, selection.expiresAt);
  }

  Future<_ExpirySelection?> _chooseExpiry(Recording recording) async {
    final action = await showModalBottomSheet<_ExpiryAction>(
      context: context,
      builder: (sheetContext) => RecordingExpirySheet(
        recording: recording,
        onPick: () => Navigator.of(sheetContext).pop(_ExpiryAction.pick),
        onClear: () => Navigator.of(sheetContext).pop(_ExpiryAction.clear),
      ),
    );
    if (!mounted || action == null) return null;
    if (action == _ExpiryAction.clear) return const _ExpirySelection(null);

    final date = await _pickExpiryDate(recording);
    if (date == null) return null;
    return _ExpirySelection(
      DateTime(date.year, date.month, date.day, 23, 59, 59),
    );
  }

  Future<DateTime?> _pickExpiryDate(Recording recording) {
    final now = DateTime.now();
    final firstDate = _startOfDay(now).add(const Duration(days: 1));
    final lastDate = DateTime(now.year + 10, 12, 31);
    final currentDate = _localDate(recording.expiresAt);
    final initialDate = _initialExpiryDate(
      currentDate: currentDate,
      firstDate: firstDate,
      lastDate: lastDate,
      fallback: _startOfDay(now).add(const Duration(days: 7)),
    );
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Delete recording after',
    );
  }

  Future<bool> _saveExpiry(Recording recording, DateTime? expiresAt) async {
    try {
      await widget.onSetExpiry(recording, expiresAt);
      if (!mounted) return false;
      _showMessage(_expirySuccessMessage(expiresAt));
      return true;
    } catch (error) {
      if (!mounted) return false;
      _showMessage('Unable to update expiry: $error');
      return false;
    }
  }

  Future<void> _openRecording(Recording recording) {
    return showDialog<void>(
      context: context,
      builder: (_) => RecordingDetailsDialog(
        recording: recording,
        onSetExpiry: () => _setExpiry(recording),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recording library',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Browse, preview, download, and control how long finalized footage is retained.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              );
              final filter = RecordingDateFilterControl(
                from: widget.filterFrom,
                to: widget.filterTo,
                onApply: widget.onApplyDateFilter,
                onClear: widget.onClearDateFilter,
              );

              if (constraints.maxWidth < 700) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [heading, const SizedBox(height: 12), filter],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 16),
                  filter,
                ],
              );
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                RecordingSliverGrid(
                  recordings: widget.recordings,
                  onOpen: _openRecording,
                  emptyMessage: widget.hasDateFilter
                      ? 'No recordings match this date filter.'
                      : 'No finalized recordings yet.',
                ),
                if (widget.loadingMore)
                  const SliverPadding(
                    padding: EdgeInsets.only(top: 24),
                    sliver: SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (!widget.hasMore && widget.recordings.isNotEmpty)
                  const SliverPadding(
                    padding: EdgeInsets.only(top: 24),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          'All recordings loaded',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 44)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _ExpiryAction { pick, clear }

class _ExpirySelection {
  const _ExpirySelection(this.expiresAt);

  final DateTime? expiresAt;
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime? _localDate(DateTime? value) {
  if (value == null) return null;
  return _startOfDay(value.toLocal());
}

DateTime _initialExpiryDate({
  required DateTime? currentDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime fallback,
}) {
  if (currentDate == null || currentDate.isBefore(firstDate)) return fallback;
  if (currentDate.isAfter(lastDate)) return fallback;
  return currentDate;
}

String _expirySuccessMessage(DateTime? expiresAt) => expiresAt == null
    ? 'Recording will now be kept indefinitely.'
    : 'Recording will expire after ${_formatExpiry(expiresAt)}.';

String _formatExpiry(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

Future<void> _ignoreDateFilter({DateTime? from, DateTime? to}) async {}

Future<void> _ignoreClearDateFilter() async {}
