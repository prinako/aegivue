part of 'recording_timeline_widget.dart';

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

List<RecordingTimelineInterval> _visibleIntervals(
  List<RecordingTimelineInterval> intervals,
  DateTime start,
  DateTime end,
) => intervals
    .where(
      (interval) =>
          interval.endTime.isAfter(start) && interval.startTime.isBefore(end),
    )
    .toList(growable: false);

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

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}:'
      '${local.second.toString().padLeft(2, '0')}';
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
