import 'dart:math' as math;

import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/domain/recording_timeline_interval.dart';
import 'package:aegivue/features/recordings/presentation/view_models/recording_timeline_view_model.dart';
import 'package:aegivue/features/recordings/presentation/widgets/selected_recording_card.dart';
import 'package:flutter/material.dart';

class RecordingTimelineWidget extends StatelessWidget {
  const RecordingTimelineWidget({
    super.key,
    required this.viewModel,
    required this.cameras,
    required this.onSetExpiry,
    this.camerasLoading = false,
    this.cameraError,
  });

  final RecordingTimelineViewModel viewModel;
  final List<Camera> cameras;
  final Future<bool> Function(Recording recording) onSetExpiry;
  final bool camerasLoading;
  final Object? cameraError;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final rows = _cameraRows(cameras, viewModel.items, viewModel.cameraIds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
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
                if (camerasLoading && cameras.isEmpty)
                  const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (cameraError != null && cameras.isEmpty)
                  const _MessageCard(
                    icon: Icons.videocam_off_outlined,
                    message: 'Camera data is unavailable.',
                  )
                else if (viewModel.loading && !viewModel.loaded)
                  const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  )
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
                    padding: EdgeInsets.only(top: 24, bottom: 8),
                    child: Text(
                      'Selected recording',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SelectedRecordingCard(
                    recording: recording,
                    cameraName: _cameraName(recording.cameraId, rows),
                    onSetExpiry: recording.protected
                        ? null
                        : () => onSetExpiry(recording),
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

class _TimelineControls extends StatelessWidget {
  const _TimelineControls({required this.viewModel});

  final RecordingTimelineViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Previous day',
              onPressed: viewModel.previousDay,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            OutlinedButton(
              onPressed: viewModel.today,
              child: const Text('Today'),
            ),
            IconButton(
              tooltip: 'Next day',
              onPressed: viewModel.nextDay,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            const SizedBox(width: 8),
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
          onSelectionChanged: (selection) =>
              viewModel.setZoom(selection.single),
        ),
      ],
    );
  }
}

class _TimelineTable extends StatelessWidget {
  const _TimelineTable({
    required this.viewModel,
    required this.rows,
    required this.onSelect,
  });

  static const double _labelWidth = 136;
  static const double _axisHeight = 38;

  final RecordingTimelineViewModel viewModel;
  final List<_CameraRow> rows;
  final ValueChanged<RecordingTimelineInterval> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseWidth = math.max(600.0, constraints.maxWidth - _labelWidth);
        final timelineWidth =
            baseWidth * (24 / viewModel.zoom.hours.toDouble());
        final layouts = [
          for (final row in rows)
            _RowLayout(row, _layOutIntervals(row.intervals)),
        ];
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
                    for (final layout in layouts)
                      SizedBox(
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  layout.row.status,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: timelineWidth,
                    child: Column(
                      children: [
                        _TimeAxis(
                          width: timelineWidth,
                          start: viewModel.dayStart,
                          end: viewModel.dayEnd,
                        ),
                        for (final layout in layouts)
                          _TimelineTrack(
                            key: ValueKey(
                              'timeline-track-${layout.row.cameraId}',
                            ),
                            layout: layout,
                            width: timelineWidth,
                            start: viewModel.dayStart,
                            end: viewModel.dayEnd,
                            selectedId: viewModel.selectedRecording?.id,
                            onSelect: onSelect,
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
  }
}

class _TimeAxis extends StatelessWidget {
  const _TimeAxis({
    required this.width,
    required this.start,
    required this.end,
  });

  final double width;
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _TimelineTable._axisHeight,
      width: width,
      child: Stack(
        children: [
          for (var index = 0; index <= 4; index++)
            Positioned(
              left: index == 4 ? null : width * index / 4,
              right: index == 4 ? 4 : null,
              top: 11,
              child: Text(
                _formatTime(_atFraction(start, end, index / 4)),
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineTrack extends StatelessWidget {
  const _TimelineTrack({
    super.key,
    required this.layout,
    required this.width,
    required this.start,
    required this.end,
    required this.selectedId,
    required this.onSelect,
  });

  final _RowLayout layout;
  final double width;
  final DateTime start;
  final DateTime end;
  final String? selectedId;
  final ValueChanged<RecordingTimelineInterval> onSelect;

  @override
  Widget build(BuildContext context) {
    final windowMicros = end.difference(start).inMicroseconds;
    return SizedBox(
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
          for (var index = 1; index < 4; index++)
            Positioned(
              left: width * index / 4,
              top: 0,
              bottom: 0,
              child: const VerticalDivider(width: 1, color: Colors.white10),
            ),
          for (final placed in layout.intervals)
            _buildSegment(context, placed, windowMicros),
        ],
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context,
    _PlacedInterval placed,
    int windowMicros,
  ) {
    final clippedStart = placed.interval.startTime.isBefore(start)
        ? start
        : placed.interval.startTime;
    final clippedEnd = placed.interval.endTime.isAfter(end)
        ? end
        : placed.interval.endTime;
    final left =
        clippedStart.difference(start).inMicroseconds / windowMicros * width;
    final segmentWidth = math.max(
      4.0,
      clippedEnd.difference(clippedStart).inMicroseconds / windowMicros * width,
    );
    final selected = selectedId == placed.interval.recordingId;
    return Positioned(
      left: left,
      top: 7 + placed.lane * 25,
      width: segmentWidth,
      height: 19,
      child: Tooltip(
        message: _tooltip(layout.row.name, placed.interval),
        child: Material(
          color: selected
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(5),
          child: InkWell(
            key: ValueKey('timeline-segment-${placed.interval.recordingId}'),
            borderRadius: BorderRadius.circular(5),
            onTap: () => onSelect(placed.interval),
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
  Widget build(BuildContext context) {
    return Padding(
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

class _RowLayout {
  const _RowLayout(this.row, this.intervals);

  final _CameraRow row;
  final List<_PlacedInterval> intervals;

  int get laneCount => intervals.fold(1, (count, interval) {
    return math.max(count, interval.lane + 1);
  });

  double get height => math.max(48, 14 + laneCount * 25);
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
        .map((interval) => interval.cameraId)
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
            .where((interval) => interval.cameraId == id)
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
  return '$cameraName\n'
      '${_formatTime(interval.startTime)}–${_formatTime(interval.endTime)}\n'
      '${minutes ~/ 60}h ${minutes % 60}m';
}
