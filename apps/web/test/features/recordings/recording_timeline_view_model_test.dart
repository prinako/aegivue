import 'dart:async';

import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/domain/recording_timeline_interval.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_camera_playback_session.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_playback.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_playback_command.dart';
import 'package:aegivue/features/recordings/presentation/view_models/recording_timeline_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to the current local calendar day', () async {
    final repository = _FakeRepository();
    final viewModel = RecordingTimelineViewModel(
      repository,
      now: () => DateTime(2026, 10, 18, 15, 30),
    );

    await viewModel.load();

    expect(viewModel.dayStart, DateTime(2026, 10, 18));
    expect(viewModel.dayEnd, DateTime(2026, 10, 19));
    expect(repository.requests.single.from, DateTime(2026, 10, 18));
    expect(repository.requests.single.to, DateTime(2026, 10, 19));
  });

  test('intersects the timeline day with the shared date filter', () async {
    final repository = _FakeRepository();
    final viewModel = RecordingTimelineViewModel(
      repository,
      now: () => DateTime(2026, 10, 18),
    );

    await viewModel.load(
      filterFrom: DateTime(2026, 10, 18, 8),
      filterTo: DateTime(2026, 10, 18, 18),
      cameraIds: {'front-door'},
    );

    expect(repository.requests.single.from, DateTime(2026, 10, 18, 8));
    expect(repository.requests.single.to, DateTime(2026, 10, 18, 18));
    expect(repository.requests.single.cameraIds, {'front-door'});
  });

  test('opens a historical to-only filter on its local day', () async {
    final repository = _FakeRepository();
    final viewModel = RecordingTimelineViewModel(
      repository,
      now: () => DateTime(2026, 10, 18),
    );

    await viewModel.load(filterTo: DateTime(2026, 10, 12, 18));

    expect(viewModel.dayStart, DateTime(2026, 10, 12));
    expect(repository.requests.single.from, DateTime(2026, 10, 12));
    expect(repository.requests.single.to, DateTime(2026, 10, 12, 18));
  });

  test(
    'day navigation preserves filters and uses local calendar days',
    () async {
      final repository = _FakeRepository();
      final viewModel = RecordingTimelineViewModel(
        repository,
        now: () => DateTime(2026, 10, 18),
      );
      await viewModel.load(cameraIds: {'garage'});

      await viewModel.previousDay();
      await viewModel.nextDay();
      await viewModel.today();

      expect(viewModel.dayStart, DateTime(2026, 10, 18));
      expect(
        repository.requests.every(
          (request) =>
              request.cameraIds.length == 1 &&
              request.cameraIds.contains('garage'),
        ),
        isTrue,
      );
    },
  );

  test('camera filter changes preserve the navigated timeline day', () async {
    final repository = _FakeRepository();
    final viewModel = RecordingTimelineViewModel(
      repository,
      now: () => DateTime(2026, 10, 18),
    );
    await viewModel.load(filterFrom: DateTime(2026, 10, 10));
    await viewModel.nextDay();

    await viewModel.syncFilters(
      filterFrom: DateTime(2026, 10, 10),
      cameraIds: {'front-door'},
    );

    expect(viewModel.dayStart, DateTime(2026, 10, 11));
    expect(viewModel.cameraIds, {'front-door'});
  });

  test('zoom changes visual scale without making another request', () async {
    final repository = _FakeRepository();
    final viewModel = RecordingTimelineViewModel(repository);
    await viewModel.load();

    viewModel.setZoom(RecordingTimelineZoom.sixHours);
    viewModel.setZoom(RecordingTimelineZoom.oneHour);

    expect(viewModel.zoom, RecordingTimelineZoom.oneHour);
    expect(repository.requests, hasLength(1));
  });

  test('a stale day response cannot replace a newer result', () async {
    final oldRequest = Completer<List<RecordingTimelineInterval>>();
    final repository = _FakeRepository()..nextResult = oldRequest.future;
    final viewModel = RecordingTimelineViewModel(
      repository,
      now: () => DateTime(2026, 10, 18),
    );

    final oldLoad = viewModel.load();
    repository.nextResult = Future.value([_interval('new')]);
    await viewModel.nextDay();
    oldRequest.complete([_interval('old')]);
    await oldLoad;

    expect(viewModel.items.single.recordingId, 'new');
  });

  test('exposes loading, empty, and error states', () async {
    final pending = Completer<List<RecordingTimelineInterval>>();
    final repository = _FakeRepository()..nextResult = pending.future;
    final viewModel = RecordingTimelineViewModel(repository);

    final load = viewModel.load();
    expect(viewModel.loading, isTrue);
    pending.complete(const []);
    await load;
    expect(viewModel.loaded, isTrue);
    expect(viewModel.items, isEmpty);

    final failure = StateError('offline');
    repository.nextResult = Future.error(failure);
    await viewModel.refresh();
    expect(viewModel.error, same(failure));
  });

  test('loads one selected recording for playback', () async {
    final repository = _FakeRepository();
    final viewModel = RecordingTimelineViewModel(repository);
    final interval = _interval('recording-1');

    await viewModel.select(interval);

    expect(repository.selectedIds, ['recording-1']);
    expect(viewModel.selectedRecording?.id, 'recording-1');
    viewModel.clearSelection();
    expect(viewModel.selectedRecording, isNull);
  });

  test('maps selection and video time to absolute timeline time', () async {
    final repository = _FakeRepository();
    final viewModel = RecordingTimelineViewModel(repository);
    final interval = _interval('recording-1');

    await viewModel.selectAt(
      interval,
      interval.startTime.add(const Duration(minutes: 3)),
    );

    expect(viewModel.selectedOffset, const Duration(minutes: 3));
    expect(
      viewModel.playbackTimestamp,
      interval.startTime.add(const Duration(minutes: 3)),
    );

    viewModel.handlePlaybackEvent(
      interval.recordingId,
      const RecordingPlaybackEvent(
        phase: RecordingPlaybackPhase.playing,
        position: Duration(minutes: 4),
        duration: Duration(minutes: 5),
      ),
    );

    expect(
      viewModel.playbackTimestamp,
      interval.startTime.add(const Duration(minutes: 4)),
    );
  });

  test(
    'tracks pause and resume without notifying the whole timeline',
    () async {
      final viewModel = RecordingTimelineViewModel(_FakeRepository());
      final interval = _interval('recording-1');
      await viewModel.select(interval);
      var timelineNotifications = 0;
      viewModel.addListener(() => timelineNotifications++);

      viewModel.handlePlaybackEvent(
        interval.recordingId,
        const RecordingPlaybackEvent(
          phase: RecordingPlaybackPhase.paused,
          position: Duration(seconds: 30),
        ),
      );
      expect(viewModel.playback.value.phase, RecordingPlaybackPhase.paused);
      viewModel.handlePlaybackEvent(
        interval.recordingId,
        const RecordingPlaybackEvent(
          phase: RecordingPlaybackPhase.playing,
          position: Duration(seconds: 31),
        ),
      );

      expect(viewModel.playback.value.phase, RecordingPlaybackPhase.playing);
      expect(timelineNotifications, 0);
    },
  );

  test(
    'ignores playback events from a previously selected recording',
    () async {
      final viewModel = RecordingTimelineViewModel(_FakeRepository());
      final first = _interval('recording-1');
      final second = _interval(
        'recording-2',
        start: DateTime.utc(2026, 10, 18, 13),
        end: DateTime.utc(2026, 10, 18, 13, 5),
      );
      await viewModel.select(first);
      await viewModel.select(second);

      viewModel.handlePlaybackEvent(
        first.recordingId,
        const RecordingPlaybackEvent(
          phase: RecordingPlaybackPhase.playing,
          position: Duration(minutes: 4),
        ),
      );

      expect(viewModel.selectedRecording?.id, second.recordingId);
      expect(viewModel.playback.value.phase, RecordingPlaybackPhase.loading);
      expect(viewModel.playback.value.position, Duration.zero);
    },
  );

  test('a stale recording detail cannot replace a newer selection', () async {
    final firstResult = Completer<Recording>();
    final repository = _FakeRepository()
      ..findOverride = (id) => id == 'recording-1'
          ? firstResult.future
          : Future.value(_recording(id));
    final viewModel = RecordingTimelineViewModel(repository);
    final first = _interval('recording-1');
    final second = _interval(
      'recording-2',
      start: DateTime.utc(2026, 10, 18, 13),
      end: DateTime.utc(2026, 10, 18, 13, 5),
    );

    final staleSelection = viewModel.select(first);
    await viewModel.select(second);
    firstResult.complete(_recording(first.recordingId));
    await staleSelection;

    expect(viewModel.selectedRecording?.id, second.recordingId);
  });

  test('filter refresh closes playback when its interval is removed', () async {
    final interval = _interval('recording-1');
    final repository = _FakeRepository()..nextResult = Future.value([interval]);
    final viewModel = RecordingTimelineViewModel(
      repository,
      now: () => DateTime(2026, 10, 18),
    );
    await viewModel.load();
    await viewModel.select(interval);
    repository.nextResult = Future.value(const []);

    await viewModel.syncFilters(cameraIds: {'garage'});

    expect(viewModel.selectedRecording, isNull);
    expect(viewModel.selectedInterval, isNull);
    expect(viewModel.playback.value.phase, RecordingPlaybackPhase.idle);
  });

  test(
    'navigates same-camera recordings in timestamp order across gaps and overlaps',
    () async {
      final repository = _FakeRepository()
        ..nextResult = Future.value([
          _interval(
            'last',
            start: DateTime.utc(2026, 10, 18, 14),
            end: DateTime.utc(2026, 10, 18, 14, 5),
          ),
          _interval('first'),
          _interval(
            'overlap',
            start: DateTime.utc(2026, 10, 18, 12, 2),
            end: DateTime.utc(2026, 10, 18, 12, 7),
          ),
          _interval(
            'other-camera',
            cameraId: 'garage',
            start: DateTime.utc(2026, 10, 18, 13),
            end: DateTime.utc(2026, 10, 18, 13, 5),
          ),
        ]);
      final viewModel = RecordingTimelineViewModel(
        repository,
        now: () => DateTime(2026, 10, 18),
      );
      await viewModel.load();
      await viewModel.select(repository.lastResult[1]);

      expect(viewModel.previousRecording, isNull);
      expect(viewModel.nextRecording?.recordingId, 'overlap');
      await viewModel.selectNext();
      expect(viewModel.nextRecording?.recordingId, 'last');
      await viewModel.selectNext();
      expect(viewModel.nextRecording, isNull);
      await viewModel.selectPrevious();
      expect(viewModel.selectedRecording?.id, 'overlap');
    },
  );

  test(
    'resolves one playback session per active camera at a shared time',
    () async {
      final repository = _FakeRepository()
        ..nextResult = Future.value([
          _interval(
            'front-recording',
            cameraId: 'front-door',
            start: DateTime.utc(2026, 10, 18, 12),
            end: DateTime.utc(2026, 10, 18, 12, 10),
          ),
          _interval(
            'garage-recording',
            cameraId: 'garage',
            start: DateTime.utc(2026, 10, 18, 11, 58),
            end: DateTime.utc(2026, 10, 18, 12, 8),
          ),
        ])
        ..findOverride = (id) => Future.value(
          _recording(
            id,
            cameraId: id.startsWith('front') ? 'front-door' : 'garage',
            start: id.startsWith('front')
                ? DateTime.utc(2026, 10, 18, 12)
                : DateTime.utc(2026, 10, 18, 11, 58),
          ),
        );
      final viewModel = RecordingTimelineViewModel(
        repository,
        now: () => DateTime.utc(2026, 10, 18, 12, 3),
      );
      viewModel.setAvailableCameraIds({'front-door', 'garage'});
      await viewModel.load(cameraIds: {'front-door', 'garage'});

      await viewModel.seekTo(DateTime.utc(2026, 10, 18, 12, 3));

      expect(viewModel.sharedTimestamp, DateTime.utc(2026, 10, 18, 12, 3));
      expect(viewModel.sessions.keys, {'front-door', 'garage'});
      expect(
        viewModel.sessions['front-door']!.offset,
        const Duration(minutes: 3),
      );
      expect(viewModel.sessions['garage']!.offset, const Duration(minutes: 5));
    },
  );

  test('keeps a no-footage session without fetching unrelated media', () async {
    final repository = _FakeRepository()
      ..nextResult = Future.value([
        _interval(
          'front-recording',
          cameraId: 'front-door',
          start: DateTime.utc(2026, 10, 18, 12),
          end: DateTime.utc(2026, 10, 18, 12, 5),
        ),
      ]);
    final viewModel = RecordingTimelineViewModel(repository);
    viewModel.setAvailableCameraIds({'front-door', 'garage'});
    await viewModel.load();

    await viewModel.seekTo(DateTime.utc(2026, 10, 18, 12, 2));

    expect(viewModel.sessions['garage']!.hasFootage, isFalse);
    expect(repository.selectedIds, ['front-recording']);
  });

  test(
    'does not start the shared clock when every camera is in a gap',
    () async {
      final viewModel = RecordingTimelineViewModel(_FakeRepository());
      viewModel.setAvailableCameraIds({'front-door', 'garage'});
      await viewModel.load();

      await viewModel.seekTo(DateTime.utc(2026, 10, 18, 12, 2));
      final commandBeforePlay = viewModel.playbackCommand.value;
      viewModel.play();

      expect(viewModel.playing, isFalse);
      expect(viewModel.playbackCommand.value, same(commandBeforePlay));
      viewModel.dispose();
    },
  );

  test(
    'switches each camera recording when the shared clock crosses a boundary',
    () async {
      final repository = _FakeRepository()
        ..nextResult = Future.value([
          _interval(
            'front-first',
            start: DateTime.utc(2026, 10, 18, 12),
            end: DateTime.utc(2026, 10, 18, 12, 5),
          ),
          _interval(
            'front-second',
            start: DateTime.utc(2026, 10, 18, 12, 5),
            end: DateTime.utc(2026, 10, 18, 12, 10),
          ),
        ]);
      final viewModel = RecordingTimelineViewModel(repository);
      viewModel.setAvailableCameraIds({'front-door'});
      await viewModel.load();
      await viewModel.seekTo(DateTime.utc(2026, 10, 18, 12, 4));
      viewModel.play();

      await viewModel.synchronize(DateTime.utc(2026, 10, 18, 12, 6));

      expect(
        viewModel.sessions['front-door']?.interval?.recordingId,
        'front-second',
      );
      expect(viewModel.playing, isTrue);
      expect(repository.selectedIds, ['front-first', 'front-second']);

      await viewModel.synchronize(DateTime.utc(2026, 10, 18, 12, 11));

      expect(viewModel.playing, isFalse);
      expect(viewModel.sessions['front-door']?.hasFootage, isFalse);
      viewModel.dispose();
    },
  );

  test(
    'an ended segment advances immediately into contiguous footage',
    () async {
      final nextRecording = Completer<Recording>();
      final repository = _FakeRepository()
        ..nextResult = Future.value([
          _interval(
            'front-first',
            start: DateTime.utc(2026, 10, 18, 12),
            end: DateTime.utc(2026, 10, 18, 12, 5),
          ),
          _interval(
            'front-second',
            start: DateTime.utc(2026, 10, 18, 12, 5),
            end: DateTime.utc(2026, 10, 18, 12, 10),
          ),
        ])
        ..findOverride = (id) => id == 'front-second'
            ? nextRecording.future
            : Future.value(_recording(id));
      final viewModel = RecordingTimelineViewModel(
        repository,
        now: () => DateTime.utc(2026, 10, 18, 12, 4),
      );
      viewModel.setAvailableCameraIds({'front-door'});
      await viewModel.load();
      await viewModel.seekTo(DateTime.utc(2026, 10, 18, 12, 4));
      viewModel.play();

      viewModel.handleCameraPlaybackEvent(
        'front-door',
        'front-first',
        const RecordingPlaybackEvent(
          phase: RecordingPlaybackPhase.ended,
          position: Duration(minutes: 5),
          duration: Duration(minutes: 5),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.sharedTimestamp, DateTime.utc(2026, 10, 18, 12, 5));
      expect(
        viewModel.sessions['front-door']?.interval?.recordingId,
        'front-second',
      );
      expect(repository.selectedIds, ['front-first', 'front-second']);

      viewModel.handleCameraPlaybackEvent(
        'front-door',
        'front-first',
        const RecordingPlaybackEvent(
          phase: RecordingPlaybackPhase.ended,
          position: Duration(minutes: 5),
        ),
      );
      expect(viewModel.playing, isTrue);
      expect(
        viewModel.sessions['front-door']?.phase,
        RecordingCameraSessionPhase.loading,
      );
      expect(repository.selectedIds, ['front-first', 'front-second']);

      nextRecording.complete(
        _recording('front-second', start: DateTime.utc(2026, 10, 18, 12, 5)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        viewModel.sessions['front-door']?.phase,
        RecordingCameraSessionPhase.ready,
      );
      expect(viewModel.playing, isTrue);
      viewModel.dispose();
    },
  );

  test('an ended segment respects pause and stops at a genuine gap', () async {
    final first = _interval(
      'front-first',
      start: DateTime.utc(2026, 10, 18, 12),
      end: DateTime.utc(2026, 10, 18, 12, 5),
    );
    final repository = _FakeRepository()..nextResult = Future.value([first]);
    final viewModel = RecordingTimelineViewModel(repository);
    viewModel.setAvailableCameraIds({'front-door'});
    await viewModel.load();
    await viewModel.seekTo(DateTime.utc(2026, 10, 18, 12, 4));

    viewModel.play();
    viewModel.pause();
    viewModel.handleCameraPlaybackEvent(
      'front-door',
      'front-first',
      const RecordingPlaybackEvent(
        phase: RecordingPlaybackPhase.ended,
        position: Duration(minutes: 5),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.sharedTimestamp, DateTime.utc(2026, 10, 18, 12, 4));
    expect(viewModel.playing, isFalse);

    await viewModel.seekTo(DateTime.utc(2026, 10, 18, 12, 4));
    viewModel.play();
    viewModel.handleCameraPlaybackEvent(
      'front-door',
      'front-first',
      const RecordingPlaybackEvent(
        phase: RecordingPlaybackPhase.ended,
        position: Duration(minutes: 5),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.sharedTimestamp, DateTime.utc(2026, 10, 18, 12, 5));
    expect(viewModel.sessions['front-door']?.hasFootage, isFalse);
    expect(viewModel.playing, isFalse);
    expect(repository.selectedIds, ['front-first']);
    viewModel.dispose();
  });

  test('caps all-camera playback at the documented resource limit', () async {
    final viewModel = RecordingTimelineViewModel(_FakeRepository());
    viewModel.setAvailableCameraIds({'e', 'd', 'c', 'b', 'a'});
    await viewModel.load();

    await viewModel.seekTo(DateTime.utc(2026, 10, 18, 12));

    expect(
      viewModel.activeCameraIds,
      hasLength(RecordingTimelineViewModel.maximumSimultaneousPlayers),
    );
    expect(viewModel.activeCameraIds, ['a', 'b', 'c', 'd']);
  });

  test(
    'chooses overlaps deterministically unless the user chose an alternative',
    () async {
      final first = _interval(
        'a-recording',
        cameraId: 'front-door',
        start: DateTime.utc(2026, 10, 18, 12),
        end: DateTime.utc(2026, 10, 18, 12, 10),
      );
      final alternative = _interval(
        'b-recording',
        cameraId: 'front-door',
        start: DateTime.utc(2026, 10, 18, 12),
        end: DateTime.utc(2026, 10, 18, 12, 10),
      );
      final repository = _FakeRepository()
        ..nextResult = Future.value([alternative, first]);
      final viewModel = RecordingTimelineViewModel(repository);
      viewModel.setAvailableCameraIds({'front-door'});
      await viewModel.load();

      await viewModel.seekTo(DateTime.utc(2026, 10, 18, 12, 2));
      expect(
        viewModel.sessions['front-door']!.interval?.recordingId,
        'a-recording',
      );

      await viewModel.selectAt(alternative, DateTime.utc(2026, 10, 18, 12, 2));
      expect(
        viewModel.sessions['front-door']!.interval?.recordingId,
        'b-recording',
      );
    },
  );

  test(
    'shares play pause and emits drift correction for a lagging camera',
    () async {
      final interval = _interval(
        'front-recording',
        cameraId: 'front-door',
        start: DateTime.utc(2026, 10, 18, 12),
        end: DateTime.utc(2026, 10, 18, 12, 10),
      );
      final repository = _FakeRepository()
        ..nextResult = Future.value([interval]);
      final viewModel = RecordingTimelineViewModel(repository);
      viewModel.setAvailableCameraIds({'front-door'});
      await viewModel.load();
      await viewModel.seekTo(DateTime.utc(2026, 10, 18, 12, 3));

      viewModel.play();
      expect(viewModel.playing, isTrue);
      viewModel.handleCameraPlaybackEvent(
        'front-door',
        'front-recording',
        const RecordingPlaybackEvent(
          phase: RecordingPlaybackPhase.playing,
          position: Duration(minutes: 2, seconds: 57),
        ),
      );

      expect(viewModel.playbackCorrection.value?.cameraId, 'front-door');
      expect(
        viewModel.playbackCorrection.value?.position,
        closeToDuration(const Duration(minutes: 3), const Duration(seconds: 1)),
      );
      viewModel.pause();
      expect(viewModel.playing, isFalse);
      viewModel.dispose();
    },
  );

  test(
    'uses fixed zoom windows and clamps navigation to the selected day',
    () async {
      final viewModel = RecordingTimelineViewModel(
        _FakeRepository(),
        now: () => DateTime(2026, 10, 18, 12, 30),
      );
      await viewModel.load();
      await viewModel.seekTo(DateTime(2026, 10, 18, 12, 30));

      viewModel.setZoom(RecordingTimelineZoom.oneHour);
      expect(viewModel.windowStart, DateTime(2026, 10, 18, 12));
      expect(viewModel.windowEnd, DateTime(2026, 10, 18, 13));
      viewModel.previousWindow();
      expect(viewModel.windowStart, DateTime(2026, 10, 18, 11));
      viewModel.nextWindow();
      expect(viewModel.windowStart, DateTime(2026, 10, 18, 12));
      expect(viewModel.sharedTimestamp, DateTime(2026, 10, 18, 12, 30).toUtc());
    },
  );

  test(
    'emits every shared seek and keeps a ready same-file session mounted',
    () async {
      final interval = _interval(
        'front-recording',
        start: DateTime.utc(2026, 10, 18, 12),
        end: DateTime.utc(2026, 10, 18, 12, 10),
      );
      final repository = _FakeRepository()
        ..nextResult = Future.value([interval]);
      final viewModel = RecordingTimelineViewModel(repository);
      viewModel.setAvailableCameraIds({'front-door'});
      await viewModel.load();
      var seekCommands = 0;
      viewModel.playbackCommand.addListener(() {
        if (viewModel.playbackCommand.value?.type ==
            RecordingPlaybackCommandType.seek) {
          seekCommands++;
        }
      });
      await viewModel.seekTo(DateTime.utc(2026, 10, 18, 12, 2));

      final secondSeek = viewModel.seekTo(DateTime.utc(2026, 10, 18, 12, 4));
      expect(
        viewModel.sessions['front-door']?.phase,
        RecordingCameraSessionPhase.ready,
      );
      await secondSeek;

      expect(seekCommands, 2);
      expect(repository.selectedIds, ['front-recording']);
    },
  );

  test(
    'does not publish unchanged playing events to the player grid',
    () async {
      final interval = _interval('front-recording');
      final repository = _FakeRepository()
        ..nextResult = Future.value([interval]);
      final viewModel = RecordingTimelineViewModel(repository);
      viewModel.setAvailableCameraIds({'front-door'});
      await viewModel.load();
      await viewModel.seekTo(DateTime.utc(2026, 10, 18, 12, 2));
      viewModel.play();
      var sessionNotifications = 0;
      viewModel.sessionsListenable.addListener(() => sessionNotifications++);

      viewModel.handleCameraPlaybackEvent(
        'front-door',
        'front-recording',
        const RecordingPlaybackEvent(
          phase: RecordingPlaybackPhase.playing,
          position: Duration(minutes: 2),
        ),
      );
      viewModel.handleCameraPlaybackEvent(
        'front-door',
        'front-recording',
        const RecordingPlaybackEvent(
          phase: RecordingPlaybackPhase.playing,
          position: Duration(minutes: 2, milliseconds: 250),
        ),
      );

      expect(sessionNotifications, 1);
      viewModel.dispose();
    },
  );
}

class _FakeRepository extends RecordingRepository {
  _FakeRepository() : super(ApiClient());

  Future<List<RecordingTimelineInterval>> nextResult = Future.value(const []);
  List<RecordingTimelineInterval> lastResult = const [];
  final List<({DateTime from, DateTime to, Set<String> cameraIds})> requests =
      [];
  final List<String> selectedIds = [];
  Future<Recording> Function(String id)? findOverride;

  @override
  Future<List<RecordingTimelineInterval>> timeline({
    required DateTime from,
    required DateTime to,
    Set<String> cameraIds = const {},
  }) {
    requests.add((from: from, to: to, cameraIds: Set.of(cameraIds)));
    return nextResult.then((value) {
      lastResult = value;
      return value;
    });
  }

  @override
  Future<Recording> find(String id) async {
    selectedIds.add(id);
    final override = findOverride;
    return override == null ? _recording(id) : override(id);
  }
}

Recording _recording(
  String id, {
  String cameraId = 'front-door',
  DateTime? start,
}) => Recording(
  id: id,
  cameraId: cameraId,
  startTime: start ?? DateTime.utc(2026, 10, 18, 12),
  endTime: (start ?? DateTime.utc(2026, 10, 18, 12)).add(
    const Duration(minutes: 10),
  ),
  container: 'mp4',
  playbackUrl: '/$id.mp4',
);

Matcher closeToDuration(Duration value, Duration delta) => predicate<Duration?>(
  (actual) => actual != null && (actual - value).abs() <= delta,
  'within $delta of $value',
);

RecordingTimelineInterval _interval(
  String id, {
  String cameraId = 'front-door',
  DateTime? start,
  DateTime? end,
}) => RecordingTimelineInterval(
  recordingId: id,
  cameraId: cameraId,
  startTime: start ?? DateTime.utc(2026, 10, 18, 12),
  endTime: end ?? DateTime.utc(2026, 10, 18, 12, 5),
);
