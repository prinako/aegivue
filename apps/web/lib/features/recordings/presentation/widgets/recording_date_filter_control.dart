import 'package:flutter/material.dart';

typedef ApplyRecordingDateFilter =
    Future<void> Function({DateTime? from, DateTime? to});

class RecordingDateFilterControl extends StatelessWidget {
  const RecordingDateFilterControl({
    super.key,
    required this.from,
    required this.to,
    required this.onApply,
    required this.onClear,
  });

  final DateTime? from;
  final DateTime? to;
  final ApplyRecordingDateFilter onApply;
  final Future<void> Function() onClear;

  bool get _active => from != null || to != null;

  Future<void> _open(BuildContext context) async {
    final selection = await showDialog<_DateFilterSelection>(
      context: context,
      builder: (_) => _RecordingDateFilterDialog(from: from, to: to),
    );
    if (selection == null) return;
    if (selection.from == null && selection.to == null) {
      await onClear();
      return;
    }
    await onApply(from: selection.from, to: selection.to);
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) {
      return OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.date_range_outlined),
        label: const Text('Filter by date'),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: () => _open(context),
          icon: const Icon(Icons.date_range_outlined),
          label: Text(_filterLabel(from, to)),
        ),
        IconButton(
          tooltip: 'Clear date filter',
          onPressed: onClear,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}

class _RecordingDateFilterDialog extends StatefulWidget {
  const _RecordingDateFilterDialog({required this.from, required this.to});

  final DateTime? from;
  final DateTime? to;

  @override
  State<_RecordingDateFilterDialog> createState() =>
      _RecordingDateFilterDialogState();
}

class _RecordingDateFilterDialogState
    extends State<_RecordingDateFilterDialog> {
  DateTime? _fromDate;
  TimeOfDay? _fromTime;
  DateTime? _toDate;
  TimeOfDay? _toTime;
  String? _error;

  @override
  void initState() {
    super.initState();
    final from = widget.from?.toLocal();
    final to = widget.to?.toLocal();
    _fromDate = _dateOnly(from);
    _toDate = _dateOnly(to);
    _fromTime = from == null || _isStartOfDay(from)
        ? null
        : TimeOfDay.fromDateTime(from);
    _toTime = to == null || _isEndOfDay(to) ? null : TimeOfDay.fromDateTime(to);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final selected = isFrom ? _fromDate : _toDate;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: selected ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: isFrom ? 'Recordings from' : 'Recordings until',
    );
    if (date == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromDate = date;
      } else {
        _toDate = date;
      }
      _error = null;
    });
  }

  Future<void> _pickTime({required bool isFrom}) async {
    final date = isFrom ? _fromDate : _toDate;
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime:
          (isFrom ? _fromTime : _toTime) ??
          (isFrom
              ? const TimeOfDay(hour: 0, minute: 0)
              : const TimeOfDay(hour: 23, minute: 59)),
      helpText: isFrom ? 'Starting at' : 'Ending at',
    );
    if (time == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromTime = time;
      } else {
        _toTime = time;
      }
      _error = null;
    });
  }

  void _clearBound({required bool isFrom}) {
    setState(() {
      if (isFrom) {
        _fromDate = null;
        _fromTime = null;
      } else {
        _toDate = null;
        _toTime = null;
      }
      _error = null;
    });
  }

  void _apply() {
    final from = _fromDate == null
        ? null
        : _combine(_fromDate!, _fromTime, endOfDay: false);
    final to = _toDate == null
        ? null
        : _combine(_toDate!, _toTime, endOfDay: true);
    if (from != null && to != null && from.isAfter(to)) {
      setState(() => _error = 'From must be earlier than or equal to To.');
      return;
    }
    Navigator.of(context).pop(_DateFilterSelection(from: from, to: to));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter recordings'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateTimeBoundRow(
              label: 'From',
              date: _fromDate,
              time: _fromTime,
              onPickDate: () => _pickDate(isFrom: true),
              onPickTime: () => _pickTime(isFrom: true),
              onClear: _fromDate == null
                  ? null
                  : () => _clearBound(isFrom: true),
            ),
            const SizedBox(height: 16),
            _DateTimeBoundRow(
              label: 'To',
              date: _toDate,
              time: _toTime,
              onPickDate: () => _pickDate(isFrom: false),
              onPickTime: () => _pickTime(isFrom: false),
              onClear: _toDate == null
                  ? null
                  : () => _clearBound(isFrom: false),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Dates without a time include the full local day.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(const _DateFilterSelection()),
          child: const Text('Clear'),
        ),
        FilledButton(onPressed: _apply, child: const Text('Apply')),
      ],
    );
  }
}

class _DateTimeBoundRow extends StatelessWidget {
  const _DateTimeBoundRow({
    required this.label,
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
    required this.onClear,
  });

  final String label;
  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: ValueKey('recording-filter-${label.toLowerCase()}-date'),
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(date == null ? 'Choose date' : _formatDate(date!)),
            ),
            OutlinedButton.icon(
              key: ValueKey('recording-filter-${label.toLowerCase()}-time'),
              onPressed: date == null ? null : onPickTime,
              icon: const Icon(Icons.schedule_outlined),
              label: Text(time == null ? 'Any time' : time!.format(context)),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Clear $label',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ],
    );
  }
}

class _DateFilterSelection {
  const _DateFilterSelection({this.from, this.to});

  final DateTime? from;
  final DateTime? to;
}

DateTime? _dateOnly(DateTime? value) =>
    value == null ? null : DateTime(value.year, value.month, value.day);

DateTime _combine(DateTime date, TimeOfDay? time, {required bool endOfDay}) {
  if (time != null) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
  if (endOfDay) {
    return DateTime(
      date.year,
      date.month,
      date.day + 1,
    ).subtract(const Duration(microseconds: 1));
  }
  return DateTime(date.year, date.month, date.day);
}

bool _isStartOfDay(DateTime value) =>
    value.hour == 0 &&
    value.minute == 0 &&
    value.second == 0 &&
    value.millisecond == 0 &&
    value.microsecond == 0;

bool _isEndOfDay(DateTime value) =>
    value.hour == 23 &&
    value.minute == 59 &&
    value.second == 59 &&
    value.millisecond == 999 &&
    value.microsecond == 999;

String _filterLabel(DateTime? from, DateTime? to) {
  if (from != null && to != null) {
    return '${_formatDateTime(from.toLocal())} – ${_formatDateTime(to.toLocal())}';
  }
  if (from != null) return 'From ${_formatDateTime(from.toLocal())}';
  return 'Until ${_formatDateTime(to!.toLocal())}';
}

String _formatDateTime(DateTime value) {
  if (_isStartOfDay(value) || _isEndOfDay(value)) return _formatDate(value);
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${_formatDate(value)}, $hour:$minute';
}

String _formatDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}
