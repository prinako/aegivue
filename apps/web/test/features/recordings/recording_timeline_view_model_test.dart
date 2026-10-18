import 'dart:async';

import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/domain/recording_timeline_interval.dart';
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
}

class _FakeRepository extends RecordingRepository {
  _FakeRepository() : super(ApiClient());

  Future<List<RecordingTimelineInterval>> nextResult = Future.value(const []);
  final List<({DateTime from, DateTime to, Set<String> cameraIds})> requests =
      [];
  final List<String> selectedIds = [];

  @override
  Future<List<RecordingTimelineInterval>> timeline({
    required DateTime from,
    required DateTime to,
    Set<String> cameraIds = const {},
  }) {
    requests.add((from: from, to: to, cameraIds: Set.of(cameraIds)));
    return nextResult;
  }

  @override
  Future<Recording> find(String id) async {
    selectedIds.add(id);
    return Recording(
      id: id,
      cameraId: 'front-door',
      startTime: DateTime.utc(2026, 10, 18, 12),
      endTime: DateTime.utc(2026, 10, 18, 12, 5),
      container: 'mp4',
      playbackUrl: '/$id.mp4',
    );
  }
}

RecordingTimelineInterval _interval(String id) => RecordingTimelineInterval(
  recordingId: id,
  cameraId: 'front-door',
  startTime: DateTime.utc(2026, 10, 18, 12),
  endTime: DateTime.utc(2026, 10, 18, 12, 5),
);
