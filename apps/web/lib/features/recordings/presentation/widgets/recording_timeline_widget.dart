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

part 'recording_timeline_layout.dart';
part 'recording_timeline_playback_workspace.dart';
part 'recording_timeline_table.dart';
part 'recording_timeline_track.dart';

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
