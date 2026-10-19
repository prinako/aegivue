part of 'recording_timeline_widget.dart';

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
