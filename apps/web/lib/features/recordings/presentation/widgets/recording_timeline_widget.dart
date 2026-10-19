import 'dart:async';
import 'dart:math' as math;

import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/domain/recording_timeline_interval.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_camera_playback_session.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_playback.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_playback_command.dart';
import 'package:aegivue/features/recordings/presentation/view_models/recording_timeline_view_model.dart';
import 'package:aegivue/features/recordings/presentation/widgets/selected_recording_card.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_player.dart';
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
  final Map<String, RecordingPlayerController> _playerControllers = {};
  final Set<String> _mutedCameraIds = {};

  @override
  void initState() {
    super.initState();
    _configureCameras();
    widget.viewModel.playbackCommand.addListener(_handlePlaybackCommand);
    widget.viewModel.playbackCorrection.addListener(_handlePlaybackCorrection);
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _isToday(widget.viewModel.dayStart, widget.now())) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant RecordingTimelineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.viewModel, widget.viewModel)) {
      oldWidget.viewModel.playbackCommand.removeListener(
        _handlePlaybackCommand,
      );
      oldWidget.viewModel.playbackCorrection.removeListener(
        _handlePlaybackCorrection,
      );
      widget.viewModel.playbackCommand.addListener(_handlePlaybackCommand);
      widget.viewModel.playbackCorrection.addListener(
        _handlePlaybackCorrection,
      );
    }
    _configureCameras();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    widget.viewModel.playbackCommand.removeListener(_handlePlaybackCommand);
    widget.viewModel.playbackCorrection.removeListener(
      _handlePlaybackCorrection,
    );
    super.dispose();
  }

  void _configureCameras() {
    widget.viewModel.setAvailableCameraIds(
      widget.cameras.map((camera) => camera.id),
    );
  }

  RecordingPlayerController _controller(String cameraId) =>
      _playerControllers.putIfAbsent(cameraId, RecordingPlayerController.new);

  void _handlePlaybackCommand() {
    final command = widget.viewModel.playbackCommand.value;
    if (command == null) return;
    final targets = command.cameraId == null
        ? _playerControllers.entries
        : _playerControllers.entries.where(
            (entry) => entry.key == command.cameraId,
          );
    for (final entry in targets) {
      switch (command.type) {
        case RecordingPlaybackCommandType.play:
          entry.value.play();
        case RecordingPlaybackCommandType.pause:
          entry.value.pause();
        case RecordingPlaybackCommandType.seek:
          final session = widget.viewModel.sessions[entry.key];
          if (session != null) entry.value.seek(session.offset);
      }
    }
  }

  void _handlePlaybackCorrection() {
    final correction = widget.viewModel.playbackCorrection.value;
    if (correction == null) return;
    _playerControllers[correction.cameraId]?.seek(correction.position);
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
                    onSelect: viewModel.selectAt,
                    onScrub: viewModel.seekTo,
                    onNoFootage: viewModel.markNoFootage,
                  ),
                ],
                _PlaybackWorkspace(
                  viewModel: viewModel,
                  rows: rows,
                  controllerFor: _controller,
                  mutedCameraIds: _mutedCameraIds,
                  onToggleMuted: (cameraId) {
                    setState(() {
                      if (!_mutedCameraIds.add(cameraId)) {
                        _mutedCameraIds.remove(cameraId);
                      }
                    });
                    _controller(
                      cameraId,
                    ).setMuted(_mutedCameraIds.contains(cameraId));
                  },
                  onSetExpiry: widget.onSetExpiry,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPlaybackWorkspace extends StatelessWidget {
  const _EmptyPlaybackWorkspace({this.timestamp});
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 18),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_outline_rounded, color: Colors.white38),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              timestamp == null
                  ? 'Select footage to begin playback.'
                  : 'No footage is available at ${_formatTimestamp(timestamp!)}.',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PlaybackWorkspace extends StatelessWidget {
  const _PlaybackWorkspace({
    required this.viewModel,
    required this.rows,
    required this.controllerFor,
    required this.mutedCameraIds,
    required this.onToggleMuted,
    required this.onSetExpiry,
  });

  final RecordingTimelineViewModel viewModel;
  final List<_CameraRow> rows;
  final RecordingPlayerController Function(String cameraId) controllerFor;
  final Set<String> mutedCameraIds;
  final ValueChanged<String> onToggleMuted;
  final Future<bool> Function(Recording recording) onSetExpiry;

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<Map<String, RecordingCameraPlaybackSession>>(
    valueListenable: viewModel.sessionsListenable,
    builder: (context, sessions, _) {
      if (sessions.isEmpty) {
        return _EmptyPlaybackWorkspace(timestamp: viewModel.noFootageTimestamp);
      }
      return Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SharedPlaybackControls(viewModel: viewModel),
            const SizedBox(height: 10),
            if (rows.length >
                RecordingTimelineViewModel.maximumSimultaneousPlayers)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Showing the first 4 cameras. Narrow the camera filter to choose others.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 2 : 1;
                final gap = columns == 2 ? 12.0 : 0.0;
                final width = (constraints.maxWidth - gap) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: 12,
                  children: [
                    for (final cameraId in viewModel.activeCameraIds)
                      SizedBox(
                        width: width,
                        child: _CameraPlaybackTile(
                          key: ValueKey('camera-playback-$cameraId'),
                          session: sessions[cameraId],
                          cameraName: _cameraName(cameraId, rows),
                          controller: controllerFor(cameraId),
                          muted: mutedCameraIds.contains(cameraId),
                          playing: viewModel.playing,
                          onToggleMuted: () => onToggleMuted(cameraId),
                          onPlaybackEvent: (recordingId, event) =>
                              viewModel.handleCameraPlaybackEvent(
                                cameraId,
                                recordingId,
                                event,
                              ),
                          onSetExpiry: onSetExpiry,
                          onClose: viewModel.clearSelection,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class _SharedPlaybackControls extends StatelessWidget {
  const _SharedPlaybackControls({required this.viewModel});
  final RecordingTimelineViewModel viewModel;

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<RecordingPlaybackSnapshot>(
    valueListenable: viewModel.playback,
    builder: (context, _, _) => Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            IconButton(
              tooltip: viewModel.playing
                  ? 'Pause all cameras'
                  : 'Play all cameras',
              onPressed: viewModel.playing ? viewModel.pause : viewModel.play,
              icon: Icon(
                viewModel.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                viewModel.sharedTimestamp == null
                    ? 'Select a timeline position'
                    : 'Shared time ${_formatTimestamp(viewModel.sharedTimestamp!)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: 'Close playback',
              onPressed: viewModel.clearSelection,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CameraPlaybackTile extends StatelessWidget {
  const _CameraPlaybackTile({
    super.key,
    required this.session,
    required this.cameraName,
    required this.controller,
    required this.muted,
    required this.playing,
    required this.onToggleMuted,
    required this.onPlaybackEvent,
    required this.onSetExpiry,
    required this.onClose,
  });

  final RecordingCameraPlaybackSession? session;
  final String cameraName;
  final RecordingPlayerController controller;
  final bool muted;
  final bool playing;
  final VoidCallback onToggleMuted;
  final void Function(String recordingId, RecordingPlaybackEvent event)
  onPlaybackEvent;
  final Future<bool> Function(Recording recording) onSetExpiry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final value = session;
    final recording = value?.recording;
    if (recording != null) {
      return SelectedRecordingCard(
        key: ValueKey('selected-recording-${recording.id}'),
        recording: recording,
        cameraName: cameraName,
        subtitle:
            '${_formatTimestamp(value!.timestamp)} • '
            '${_sessionStatus(value)}',
        playerController: controller,
        initialPosition: value.offset,
        autoplay: playing,
        onPlaybackEvent: (event) => onPlaybackEvent(recording.id, event),
        playbackControls: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: muted ? 'Unmute $cameraName' : 'Mute $cameraName',
              onPressed: onToggleMuted,
              icon: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              ),
            ),
            IconButton(
              tooltip: 'Fullscreen $cameraName',
              onPressed: controller.toggleFullscreen,
              icon: const Icon(Icons.fullscreen_rounded),
            ),
          ],
        ),
        onSetExpiry: recording.protected ? null : () => onSetExpiry(recording),
        onClose: onClose,
        updatingExpiry: false,
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value?.phase == RecordingCameraSessionPhase.loading)
                const CircularProgressIndicator()
              else
                Icon(
                  value?.phase == RecordingCameraSessionPhase.error
                      ? Icons.error_outline_rounded
                      : Icons.videocam_off_outlined,
                  color: Colors.white38,
                ),
              const SizedBox(height: 8),
              Text(
                cameraName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                _sessionStatus(value),
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sessionStatus(RecordingCameraPlaybackSession? session) {
  if (session == null) return 'No footage';
  return switch (session.phase) {
    RecordingCameraSessionPhase.noFootage => 'No footage',
    RecordingCameraSessionPhase.loading => 'Loading',
    RecordingCameraSessionPhase.ready => switch (session.playback.phase) {
      RecordingPlaybackPhase.playing => 'Playing',
      RecordingPlaybackPhase.paused => 'Paused',
      RecordingPlaybackPhase.ended => 'Ended',
      _ => 'Ready',
    },
    RecordingCameraSessionPhase.error => session.error ?? 'Playback error',
  };
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
            tooltip: viewModel.zoom == RecordingTimelineZoom.day
                ? 'Previous day'
                : 'Previous window',
            visualDensity: VisualDensity.compact,
            onPressed: viewModel.zoom == RecordingTimelineZoom.day
                ? viewModel.previousDay
                : viewModel.previousWindow,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          OutlinedButton(
            onPressed: viewModel.today,
            child: const Text('Today'),
          ),
          IconButton(
            tooltip: viewModel.zoom == RecordingTimelineZoom.day
                ? 'Next day'
                : 'Next window',
            visualDensity: VisualDensity.compact,
            onPressed: viewModel.zoom == RecordingTimelineZoom.day
                ? viewModel.nextDay
                : viewModel.nextWindow,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          const SizedBox(width: 6),
          Text(
            viewModel.zoom == RecordingTimelineZoom.day
                ? _formatDay(viewModel.dayStart)
                : '${_formatDay(viewModel.dayStart)}  '
                      '${_formatTime(viewModel.windowStart)}–'
                      '${_formatTime(viewModel.windowEnd)}',
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
                onHorizontalDragStart: (details) => _beginScrub(
                  details,
                  windowStart,
                  windowEnd,
                  timelineWidth,
                ),
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
