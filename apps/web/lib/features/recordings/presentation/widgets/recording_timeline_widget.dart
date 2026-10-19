import 'dart:async';
import 'dart:math' as math;

import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/domain/recording_timeline_interval.dart';
import 'package:aegivue/features/recordings/presentation/view_models/recording_timeline_view_model.dart';
import 'package:aegivue/features/recordings/presentation/widgets/selected_recording_card.dart';
import 'package:flutter/material.dart';

class RecordingTimelineWidget extends StatefulWidget {
  const RecordingTimelineWidget({
    super.key,
    required this.viewModel,
    required this.cameras,
    required this.onSetExpiry,
    this.camerasLoading = false,
    this.cameraError,
    this.now = DateTime.now,
  });

  final RecordingTimelineViewModel viewModel;
  final List<Camera> cameras;
  final Future<bool> Function(Recording recording) onSetExpiry;
  final bool camerasLoading;
  final Object? cameraError;
  final DateTime Function() now;

  @override
  State<RecordingTimelineWidget> createState() =>
      _RecordingTimelineWidgetState();
}

class _RecordingTimelineWidgetState extends State<RecordingTimelineWidget> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _isToday(widget.viewModel.dayStart, widget.now())) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.viewModel,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final viewModel = widget.viewModel;
    final rows = _cameraRows(
      widget.cameras,
      viewModel.items,
      viewModel.cameraIds,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
          child: _TimelineControls(viewModel: viewModel),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: viewModel.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              children: [
                if (viewModel.error != null)
                  _MessageCard(
                    icon: Icons.error_outline_rounded,
                    message: 'Unable to load recording timeline.',
                    actionLabel: 'Retry',
                    onAction: viewModel.refresh,
                  ),
                if (widget.camerasLoading && widget.cameras.isEmpty)
                  const _LoadingState()
                else if (widget.cameraError != null && widget.cameras.isEmpty)
                  const _MessageCard(
                    icon: Icons.videocam_off_outlined,
                    message: 'Camera data is unavailable.',
                  )
                else if (viewModel.loading && !viewModel.loaded)
                  const _LoadingState()
                else if (rows.isEmpty)
                  const _MessageCard(
                    icon: Icons.videocam_off_outlined,
                    message: 'No cameras available.',
                  )
                else ...[
                  if (viewModel.items.isEmpty && viewModel.error == null)
                    const _MessageCard(
                      icon: Icons.timeline_rounded,
                      message: 'No recordings in this time window.',
                    ),
                  _TimelineTable(
                    viewModel: viewModel,
                    rows: rows,
                    now: widget.now,
                    onSelect: viewModel.select,
                  ),
                ],
                if (viewModel.selectionLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (viewModel.selectionError != null)
                  const _MessageCard(
                    icon: Icons.error_outline_rounded,
                    message: 'Unable to open the selected recording.',
                  ),
                if (viewModel.selectedRecording case final recording?) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 18, bottom: 8),
                    child: Text(
                      'Selected recording',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SelectedRecordingCard(
                    key: ValueKey('selected-recording-${recording.id}'),
                    recording: recording,
                    cameraName: _cameraName(recording.cameraId, rows),
                    onSetExpiry: recording.protected
                        ? null
                        : () => widget.onSetExpiry(recording),
                    onClose: viewModel.clearSelection,
                    updatingExpiry: false,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 240,
    child: Center(child: CircularProgressIndicator()),
  );
}

class _TimelineControls extends StatelessWidget {
  const _TimelineControls({required this.viewModel});
  final RecordingTimelineViewModel viewModel;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    runSpacing: 6,
    children: [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'Previous day',
            visualDensity: VisualDensity.compact,
            onPressed: viewModel.previousDay,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          OutlinedButton(
            onPressed: viewModel.today,
            child: const Text('Today'),
          ),
          IconButton(
            tooltip: 'Next day',
            visualDensity: VisualDensity.compact,
            onPressed: viewModel.nextDay,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(width: 6),
          Text(
            _formatDay(viewModel.dayStart),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      SegmentedButton<RecordingTimelineZoom>(
        showSelectedIcon: false,
        segments: [
          for (final zoom in RecordingTimelineZoom.values)
            ButtonSegment(value: zoom, label: Text(zoom.label)),
        ],
        selected: {viewModel.zoom},
        onSelectionChanged: (selection) => viewModel.setZoom(selection.single),
      ),
    ],
  );
}

class _TimelineTable extends StatefulWidget {
  const _TimelineTable({
    required this.viewModel,
    required this.rows,
    required this.now,
    required this.onSelect,
  });
  final RecordingTimelineViewModel viewModel;
  final List<_CameraRow> rows;
  final DateTime Function() now;
  final ValueChanged<RecordingTimelineInterval> onSelect;

  @override
  State<_TimelineTable> createState() => _TimelineTableState();
}

class _TimelineTableState extends State<_TimelineTable> {
  static const double _labelWidth = 136;
  static const double _axisHeight = 38;
  final ScrollController _horizontal = ScrollController();
  late RecordingTimelineZoom _lastZoom;
  double _timelineWidth = 0;

  @override
  void initState() {
    super.initState();
    _lastZoom = RecordingTimelineZoom.day;
  }

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewportWidth = math.max(1.0, constraints.maxWidth - _labelWidth);
      final timelineWidth =
          math.max(600.0, viewportWidth) *
          (24 / widget.viewModel.zoom.hours.toDouble());
      _preserveZoomAnchor(timelineWidth, viewportWidth);
      _timelineWidth = timelineWidth;
      final coverage = widget.viewModel.zoom != RecordingTimelineZoom.oneHour;
      final layouts = [
        for (final row in widget.rows)
          _RowLayout(
            row,
            coverage ? const [] : _layOutIntervals(row.intervals),
            coverage ? _mergeCoverage(row.intervals) : const [],
          ),
      ];
      final now = widget.now();
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _labelWidth,
              child: Column(
                children: [
                  const SizedBox(
                    height: _axisHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          'Camera',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  for (final layout in layouts) _CameraLabel(layout: layout),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('timeline-horizontal-scroll'),
                controller: _horizontal,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: timelineWidth,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          _TimeAxis(
                            width: timelineWidth,
                            start: widget.viewModel.dayStart,
                            end: widget.viewModel.dayEnd,
                            zoom: widget.viewModel.zoom,
                          ),
                          for (final layout in layouts)
                            _TimelineTrack(
                              key: ValueKey(
                                'timeline-track-${layout.row.cameraId}',
                              ),
                              layout: layout,
                              width: timelineWidth,
                              start: widget.viewModel.dayStart,
                              end: widget.viewModel.dayEnd,
                              zoom: widget.viewModel.zoom,
                              selectedId:
                                  widget.viewModel.selectedRecording?.id,
                              onSelect: widget.onSelect,
                            ),
                        ],
                      ),
                      if (_isToday(widget.viewModel.dayStart, now))
                        Positioned(
                          key: const ValueKey('timeline-current-time'),
                          left: _position(
                            now,
                            widget.viewModel.dayStart,
                            widget.viewModel.dayEnd,
                            timelineWidth,
                          ),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiary.withValues(alpha: 0.75),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  void _preserveZoomAnchor(double newWidth, double viewportWidth) {
    final zoom = widget.viewModel.zoom;
    if (zoom == _lastZoom) return;
    DateTime anchor;
    final selectedId = widget.viewModel.selectedRecording?.id;
    final selected = widget.viewModel.items.where(
      (item) => item.recordingId == selectedId,
    );
    if (selected.isNotEmpty) {
      final interval = selected.first;
      anchor = interval.startTime.add(interval.duration ~/ 2);
    } else if (_horizontal.hasClients && _timelineWidth > 0) {
      final center =
          _horizontal.offset + _horizontal.position.viewportDimension / 2;
      anchor = _atFraction(
        widget.viewModel.dayStart,
        widget.viewModel.dayEnd,
        (center / _timelineWidth).clamp(0, 1),
      );
    } else if (_isToday(widget.viewModel.dayStart, widget.now())) {
      anchor = widget.now();
    } else {
      anchor = _atFraction(
        widget.viewModel.dayStart,
        widget.viewModel.dayEnd,
        0.5,
      );
    }
    _lastZoom = zoom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_horizontal.hasClients) return;
      final fraction =
          anchor.difference(widget.viewModel.dayStart).inMicroseconds /
          widget.viewModel.dayEnd
              .difference(widget.viewModel.dayStart)
              .inMicroseconds;
      final target = fraction * newWidth - viewportWidth / 2;
      _horizontal.jumpTo(target.clamp(0, _horizontal.position.maxScrollExtent));
    });
  }
}

class _CameraLabel extends StatelessWidget {
  const _CameraLabel({required this.layout});
  final _RowLayout layout;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: layout.height,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              layout.row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              layout.row.status,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({
    required this.width,
    required this.start,
    required this.end,
    required this.zoom,
  });
  final double width;
  final DateTime start;
  final DateTime end;
  final RecordingTimelineZoom zoom;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _TimelineTableState._axisHeight,
    width: width,
    child: Stack(
      children: [
        for (final tick in _timeTicks(start, end, zoom))
          Positioned(
            left: _position(tick, start, end, width),
            top: 0,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 1, height: 7, color: Colors.white24),
                const SizedBox(height: 3),
                Transform.translate(
                  offset: const Offset(3, 0),
                  child: Text(
                    _formatTime(tick),
                    key: ValueKey('timeline-tick-${_formatTime(tick)}'),
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _TimelineTrack extends StatelessWidget {
  const _TimelineTrack({
    super.key,
    required this.layout,
    required this.width,
    required this.start,
    required this.end,
    required this.zoom,
    required this.selectedId,
    required this.onSelect,
  });
  final _RowLayout layout;
  final double width;
  final DateTime start;
  final DateTime end;
  final RecordingTimelineZoom zoom;
  final String? selectedId;
  final ValueChanged<RecordingTimelineInterval> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: layout.height,
    child: Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.025),
              border: const Border(top: BorderSide(color: Colors.white10)),
            ),
          ),
        ),
        for (final tick in _timeTicks(start, end, zoom).skip(1))
          Positioned(
            left: _position(tick, start, end, width),
            top: 0,
            bottom: 0,
            child: Container(width: 1, color: Colors.white10),
          ),
        for (final coverage in layout.coverage)
          _coverageSegment(context, coverage),
        for (final placed in layout.intervals) _detailSegment(context, placed),
      ],
    ),
  );

  Widget _coverageSegment(BuildContext context, _CoverageInterval coverage) {
    final geometry = _geometry(coverage.start, coverage.end, start, end, width);
    final selected = coverage.intervals.any(
      (item) => item.recordingId == selectedId,
    );
    return Positioned(
      left: geometry.left,
      top: 12,
      width: geometry.width,
      height: 18,
      child: Tooltip(
        message:
            '${layout.row.name}\n${_formatTime(coverage.start)}–'
            '${_formatTime(coverage.end)}\n${coverage.intervals.length} recording(s)',
        child: Material(
          key: ValueKey('timeline-coverage-${layout.row.cameraId}'),
          color: selected
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTapUp: (details) =>
                _selectCoverage(context, coverage, details.localPosition.dx),
          ),
        ),
      ),
    );
  }

  Future<void> _selectCoverage(
    BuildContext context,
    _CoverageInterval coverage,
    double localX,
  ) async {
    final segmentWidth = _geometry(
      coverage.start,
      coverage.end,
      start,
      end,
      width,
    ).width;
    final clicked = _atFraction(
      coverage.start,
      coverage.end,
      (localX / segmentWidth).clamp(0.0, 1.0),
    );
    var matches = coverage.intervals
        .where(
          (item) =>
              !clicked.isBefore(item.startTime) &&
              clicked.isBefore(item.endTime),
        )
        .toList();
    if (matches.isEmpty) matches = coverage.intervals;
    if (matches.length == 1) {
      onSelect(matches.single);
      return;
    }
    final chosen = await showModalBottomSheet<RecordingTimelineInterval>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose recording')),
            for (final interval in matches)
              ListTile(
                title: Text(
                  '${_formatTime(interval.startTime)}–${_formatTime(interval.endTime)}',
                ),
                subtitle: Text(interval.recordingId),
                onTap: () => Navigator.pop(sheetContext, interval),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) onSelect(chosen);
  }

  Widget _detailSegment(BuildContext context, _PlacedInterval placed) {
    final interval = placed.interval;
    final geometry = _geometry(
      interval.startTime,
      interval.endTime,
      start,
      end,
      width,
    );
    final selected = selectedId == interval.recordingId;
    return Positioned(
      left: geometry.left,
      top: 7 + placed.lane * 25,
      width: geometry.width,
      height: 19,
      child: Tooltip(
        message: _tooltip(layout.row.name, interval),
        child: Material(
          color: selected
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(5),
          child: InkWell(
            key: ValueKey('timeline-segment-${interval.recordingId}'),
            borderRadius: BorderRadius.circular(5),
            onTap: () => onSelect(interval),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white38),
        const SizedBox(width: 8),
        Flexible(child: Text(message)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 8),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

class _CameraRow {
  const _CameraRow({
    required this.cameraId,
    required this.name,
    required this.status,
    required this.intervals,
  });
  final String cameraId;
  final String name;
  final String status;
  final List<RecordingTimelineInterval> intervals;
}

class _PlacedInterval {
  const _PlacedInterval(this.interval, this.lane);
  final RecordingTimelineInterval interval;
  final int lane;
}

class _CoverageInterval {
  const _CoverageInterval(this.start, this.end, this.intervals);
  final DateTime start;
  final DateTime end;
  final List<RecordingTimelineInterval> intervals;
}

class _RowLayout {
  const _RowLayout(this.row, this.intervals, this.coverage);
  final _CameraRow row;
  final List<_PlacedInterval> intervals;
  final List<_CoverageInterval> coverage;
  int get laneCount => intervals.fold(
    1,
    (count, interval) => math.max(count, interval.lane + 1),
  );
  double get height =>
      coverage.isNotEmpty ? 48 : math.max(48, 14 + laneCount * 25);
}

class _SegmentGeometry {
  const _SegmentGeometry(this.left, this.width);
  final double left;
  final double width;
}

List<_CameraRow> _cameraRows(
  List<Camera> cameras,
  List<RecordingTimelineInterval> intervals,
  Set<String> selectedCameraIds,
) {
  final camerasById = {for (final camera in cameras) camera.id: camera};
  final ids = selectedCameraIds.isEmpty
      ? cameras.map((camera) => camera.id).toSet()
      : selectedCameraIds.toSet();
  ids.addAll(
    intervals
        .map((item) => item.cameraId)
        .where(
          (id) => selectedCameraIds.isEmpty || selectedCameraIds.contains(id),
        ),
  );
  final rows = [
    for (final id in ids)
      _CameraRow(
        cameraId: id,
        name: camerasById[id]?.name ?? '$id (unavailable)',
        status: _cameraStatus(camerasById[id]),
        intervals: intervals
            .where((item) => item.cameraId == id)
            .toList(growable: false),
      ),
  ];
  rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return rows;
}

List<_PlacedInterval> _layOutIntervals(
  List<RecordingTimelineInterval> intervals,
) {
  final sorted = [...intervals]
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  final laneEnds = <DateTime>[];
  final placed = <_PlacedInterval>[];
  for (final interval in sorted) {
    var lane = laneEnds.indexWhere((end) => !end.isAfter(interval.startTime));
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(interval.endTime);
    } else {
      laneEnds[lane] = interval.endTime;
    }
    placed.add(_PlacedInterval(interval, lane));
  }
  return placed;
}

List<_CoverageInterval> _mergeCoverage(
  List<RecordingTimelineInterval> intervals,
) {
  final sorted = [...intervals]
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  final result = <_CoverageInterval>[];
  for (final interval in sorted) {
    if (result.isEmpty || interval.startTime.isAfter(result.last.end)) {
      result.add(
        _CoverageInterval(interval.startTime, interval.endTime, [interval]),
      );
      continue;
    }
    final current = result.removeLast();
    result.add(
      _CoverageInterval(
        current.start,
        interval.endTime.isAfter(current.end) ? interval.endTime : current.end,
        [...current.intervals, interval],
      ),
    );
  }
  return result;
}

List<DateTime> _timeTicks(
  DateTime start,
  DateTime end,
  RecordingTimelineZoom zoom,
) {
  final minutes = switch (zoom) {
    RecordingTimelineZoom.day => 240,
    RecordingTimelineZoom.sixHours => 60,
    RecordingTimelineZoom.oneHour => 15,
  };
  final ticks = <DateTime>[];
  var tick = start;
  while (tick.isBefore(end)) {
    ticks.add(tick);
    tick = DateTime(
      tick.year,
      tick.month,
      tick.day,
      tick.hour,
      tick.minute + minutes,
    );
  }
  return ticks;
}

_SegmentGeometry _geometry(
  DateTime valueStart,
  DateTime valueEnd,
  DateTime start,
  DateTime end,
  double width,
) {
  final clippedStart = valueStart.isBefore(start) ? start : valueStart;
  final clippedEnd = valueEnd.isAfter(end) ? end : valueEnd;
  final total = end.difference(start).inMicroseconds;
  return _SegmentGeometry(
    clippedStart.difference(start).inMicroseconds / total * width,
    math.max(
      4,
      clippedEnd.difference(clippedStart).inMicroseconds / total * width,
    ),
  );
}

double _position(DateTime value, DateTime start, DateTime end, double width) =>
    value.difference(start).inMicroseconds /
    end.difference(start).inMicroseconds *
    width;

bool _isToday(DateTime day, DateTime now) {
  final local = now.toLocal();
  return day.year == local.year &&
      day.month == local.month &&
      day.day == local.day;
}

String _cameraStatus(Camera? camera) {
  if (camera == null) return 'Unavailable';
  if (!camera.enabled) return 'Disabled';
  return camera.runtimeState == 'online' ? 'Online' : 'Offline';
}

String _cameraName(String cameraId, List<_CameraRow> rows) {
  for (final row in rows) {
    if (row.cameraId == cameraId) return row.name;
  }
  return cameraId;
}

String _formatDay(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

DateTime _atFraction(DateTime start, DateTime end, double fraction) =>
    start.add(
      Duration(
        microseconds: (end.difference(start).inMicroseconds * fraction).round(),
      ),
    );

String _tooltip(String cameraName, RecordingTimelineInterval interval) {
  final minutes = interval.duration.inMinutes;
  return '$cameraName\n${_formatTime(interval.startTime)}–'
      '${_formatTime(interval.endTime)}\n${minutes ~/ 60}h ${minutes % 60}m';
}
