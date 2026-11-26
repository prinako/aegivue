part of 'recording_timeline_widget.dart';

class _TimelineTrack extends StatelessWidget {
  const _TimelineTrack({
    super.key,
    required this.layout,
    required this.width,
    required this.start,
    required this.end,
    required this.zoom,
    required this.selectedIds,
    required this.onSelect,
    required this.onNoFootage,
  });
  final _RowLayout layout;
  final double width;
  final DateTime start;
  final DateTime end;
  final RecordingTimelineZoom zoom;
  final Set<String> selectedIds;
  final Future<void> Function(RecordingTimelineInterval, DateTime) onSelect;
  final ValueChanged<DateTime> onNoFootage;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: layout.height,
    child: Stack(
      children: [
        Positioned.fill(
          child: Material(
            color: Colors.white.withValues(alpha: 0.025),
            child: InkWell(
              key: ValueKey('timeline-gap-${layout.row.cameraId}'),
              onTapUp: (details) => onNoFootage(
                _atFraction(
                  start,
                  end,
                  (details.localPosition.dx / width).clamp(0.0, 1.0),
                ),
              ),
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
      (item) => selectedIds.contains(item.recordingId),
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
      await onSelect(matches.single, clicked);
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
    if (chosen != null) await onSelect(chosen, clicked);
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
    final selected = selectedIds.contains(interval.recordingId);
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
            onTapUp: (details) {
              final clicked = _atFraction(
                interval.startTime,
                interval.endTime,
                (details.localPosition.dx / geometry.width).clamp(0.0, 1.0),
              );
              onSelect(interval, clicked);
            },
          ),
        ),
      ),
    );
  }
}
