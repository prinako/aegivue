part of 'recording_timeline_widget.dart';

class _TimelineTable extends StatefulWidget {
  const _TimelineTable({
    required this.viewModel,
    required this.rows,
    required this.now,
    required this.onSelect,
    required this.onScrub,
    required this.onNoFootage,
  });
  final RecordingTimelineViewModel viewModel;
  final List<_CameraRow> rows;
  final DateTime Function() now;
  final Future<void> Function(RecordingTimelineInterval, DateTime) onSelect;
  final Future<void> Function(DateTime) onScrub;
  final ValueChanged<DateTime> onNoFootage;

  @override
  State<_TimelineTable> createState() => _TimelineTableState();
}

class _TimelineTableState extends State<_TimelineTable> {
  static const double _labelWidth = 136;
  static const double _axisHeight = 38;
  DateTime? _scrubPreview;

  void _beginScrub(
    DragStartDetails details,
    DateTime windowStart,
    DateTime windowEnd,
    double width,
  ) {
    _setScrubPreview(details.localPosition.dx, windowStart, windowEnd, width);
  }

  void _updateScrub(
    DragUpdateDetails details,
    DateTime windowStart,
    DateTime windowEnd,
    double width,
  ) {
    _setScrubPreview(details.localPosition.dx, windowStart, windowEnd, width);
  }

  void _finishScrub() {
    final timestamp = _scrubPreview;
    _clearScrub();
    if (timestamp != null) unawaited(widget.onScrub(timestamp));
  }

  void _setScrubPreview(
    double x,
    DateTime windowStart,
    DateTime windowEnd,
    double width,
  ) {
    final timestamp = _atFraction(
      windowStart,
      windowEnd,
      (x / width).clamp(0.0, 1.0),
    );
    if (timestamp == _scrubPreview) return;
    setState(() => _scrubPreview = timestamp);
  }

  void _clearScrub() {
    if (_scrubPreview != null) setState(() => _scrubPreview = null);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final viewportWidth = math.max(1.0, constraints.maxWidth - _labelWidth);
      final timelineWidth = viewportWidth;
      final windowStart = widget.viewModel.windowStart;
      final windowEnd = widget.viewModel.windowEnd;
      final coverage = widget.viewModel.zoom != RecordingTimelineZoom.oneHour;
      final layouts = [
        for (final row in widget.rows)
          if (_visibleIntervals(row.intervals, windowStart, windowEnd)
              case final visible)
            _RowLayout(
              row,
              coverage ? const [] : _layOutIntervals(visible),
              coverage ? _mergeCoverage(visible) : const [],
            ),
      ];
      final now = widget.now();
      return Card(
        margin: EdgeInsets.zero,
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
              child: GestureDetector(
                key: const ValueKey('timeline-scrub-surface'),
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (details) =>
                    _beginScrub(details, windowStart, windowEnd, timelineWidth),
                onHorizontalDragUpdate: (details) => _updateScrub(
                  details,
                  windowStart,
                  windowEnd,
                  timelineWidth,
                ),
                onHorizontalDragEnd: (_) => _finishScrub(),
                onHorizontalDragCancel: _clearScrub,
                child: SizedBox(
                  width: timelineWidth,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Column(
                        children: [
                          _TimeAxis(
                            width: timelineWidth,
                            start: windowStart,
                            end: windowEnd,
                            zoom: widget.viewModel.zoom,
                          ),
                          for (final layout in layouts)
                            _TimelineTrack(
                              key: ValueKey(
                                'timeline-track-${layout.row.cameraId}',
                              ),
                              layout: layout,
                              width: timelineWidth,
                              start: windowStart,
                              end: windowEnd,
                              zoom: widget.viewModel.zoom,
                              selectedIds: {
                                for (final session
                                    in widget.viewModel.sessions.values)
                                  ?session.interval?.recordingId,
                              },
                              onSelect: widget.onSelect,
                              onNoFootage: widget.onNoFootage,
                            ),
                        ],
                      ),
                      if (_isToday(widget.viewModel.dayStart, now) &&
                          !now.isBefore(windowStart) &&
                          now.isBefore(windowEnd))
                        Positioned(
                          key: const ValueKey('timeline-current-time'),
                          left: _position(
                            now,
                            windowStart,
                            windowEnd,
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
                      ValueListenableBuilder<RecordingPlaybackSnapshot>(
                        valueListenable: widget.viewModel.playback,
                        builder: (context, _, _) {
                          final timestamp = widget.viewModel.playbackTimestamp;
                          if (timestamp == null ||
                              timestamp.isBefore(windowStart) ||
                              !timestamp.isBefore(windowEnd)) {
                            return const SizedBox.shrink();
                          }
                          return Positioned(
                            key: const ValueKey('timeline-playback-playhead'),
                            left: _position(
                              timestamp,
                              windowStart,
                              windowEnd,
                              timelineWidth,
                            ),
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: 2,
                              color: Colors.amberAccent,
                            ),
                          );
                        },
                      ),
                      if (_scrubPreview case final preview?) ...[
                        Positioned(
                          key: const ValueKey('timeline-scrub-preview'),
                          left: _position(
                            preview,
                            windowStart,
                            windowEnd,
                            timelineWidth,
                          ),
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: Container(
                              width: 2,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                        Positioned(
                          left:
                              (_position(
                                        preview,
                                        windowStart,
                                        windowEnd,
                                        timelineWidth,
                                      ) -
                                      34)
                                  .clamp(
                                    0.0,
                                    math.max(0.0, timelineWidth - 68),
                                  ),
                          top: 4,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                child: Text(
                                  _formatTimestamp(preview),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
