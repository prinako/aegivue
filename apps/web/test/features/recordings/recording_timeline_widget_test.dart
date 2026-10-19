@TestOn('browser')
library;

import 'dart:async';

import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/domain/camera_connection.dart';
import 'package:aegivue/features/cameras/domain/camera_motion_config.dart';
import 'package:aegivue/features/cameras/domain/camera_recording_config.dart';
import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/domain/recording_timeline_interval.dart';
import 'package:aegivue/features/recordings/presentation/view_models/recording_timeline_view_model.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_library.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_player.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_timeline_widget.dart';
import 'package:aegivue/features/recordings/presentation/widgets/selected_recording_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switches between the virtualized grid and timeline', (
    tester,
  ) async {
    final repository = _TimelineRepository()..result = Future.value(const []);
    final viewModel = _viewModel(repository);

    await tester.pumpWidget(_library(viewModel));

    expect(find.text('No finalized recordings yet.'), findsOneWidget);
    await tester.tap(find.text('Timeline'));
    await tester.pumpAndSettle();

    expect(find.byType(RecordingTimelineWidget), findsOneWidget);
    expect(repository.requests, hasLength(1));
    await tester.tap(find.text('Grid'));
    await tester.pump();
    expect(find.text('No finalized recordings yet.'), findsOneWidget);
  });

  testWidgets('shows camera rows and positions intervals from timestamps', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([
        _interval(
          'recording-1',
          start: DateTime(2026, 10, 18, 6),
          end: DateTime(2026, 10, 18, 7),
        ),
      ]);
    final viewModel = _viewModel(repository);
    await viewModel.load();

    await tester.pumpWidget(_timeline(viewModel));

    expect(find.text('Front Door'), findsOneWidget);
    expect(find.text('Garage'), findsOneWidget);
    final track = tester.getRect(
      find.byKey(const ValueKey('timeline-track-front-door')),
    );
    final segment = tester.getRect(
      find.byKey(const ValueKey('timeline-segment-recording-1')),
    );
    expect(segment.left - track.left, closeTo(track.width * 0.25, 1));
    expect(segment.width, closeTo(track.width / 24, 1));
  });

  testWidgets('keeps overlapping intervals individually clickable', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([
        _interval(
          'recording-1',
          start: DateTime(2026, 10, 18, 6),
          end: DateTime(2026, 10, 18, 7),
        ),
        _interval(
          'recording-2',
          start: DateTime(2026, 10, 18, 6, 30),
          end: DateTime(2026, 10, 18, 7, 30),
        ),
      ]);
    final viewModel = _viewModel(repository);
    await viewModel.load();

    await tester.pumpWidget(_timeline(viewModel));

    final first = tester.getRect(
      find.byKey(const ValueKey('timeline-segment-recording-1')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('timeline-segment-recording-2')),
    );
    expect(first.top, isNot(second.top));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip && widget.message?.contains('Front Door') == true,
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('shows only cameras selected by the shared filter', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([
        _interval('front-recording'),
        RecordingTimelineInterval(
          recordingId: 'garage-recording',
          cameraId: 'garage',
          startTime: DateTime(2026, 10, 18, 13),
          endTime: DateTime(2026, 10, 18, 13, 5),
        ),
      ]);
    final viewModel = _viewModel(repository);
    await viewModel.load(cameraIds: {'front-door'});

    await tester.pumpWidget(_timeline(viewModel));

    expect(find.text('Front Door'), findsOneWidget);
    expect(find.text('Garage'), findsNothing);
    expect(
      find.byKey(const ValueKey('timeline-segment-garage-recording')),
      findsNothing,
    );
  });

  testWidgets('navigates dates and applies zoom presets', (tester) async {
    final repository = _TimelineRepository();
    final viewModel = _viewModel(repository);
    await viewModel.load();

    await tester.pumpWidget(_timeline(viewModel));
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    expect(viewModel.dayStart, DateTime(2026, 10, 17));

    await tester.tap(find.text('6h'));
    await tester.pump();
    expect(viewModel.zoom, RecordingTimelineZoom.sixHours);
    final track = tester.getSize(
      find.byKey(const ValueKey('timeline-track-front-door')),
    );
    expect(track.width, greaterThan(2000));
  });

  testWidgets('selects a segment and shows one playback card', (tester) async {
    final repository = _TimelineRepository()
      ..result = Future.value([_interval('recording-1')]);
    final viewModel = _viewModel(repository);
    await viewModel.load();

    await tester.pumpWidget(_timeline(viewModel));
    await tester.tap(
      find.byKey(const ValueKey('timeline-segment-recording-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Selected recording'), findsOneWidget);
    expect(find.byType(SelectedRecordingCard), findsOneWidget);
    expect(find.byType(RecordingPlayer), findsOneWidget);
    expect(repository.selectedIds, ['recording-1']);
  });

  testWidgets('shows loading, empty, and error states', (tester) async {
    final pending = Completer<List<RecordingTimelineInterval>>();
    final repository = _TimelineRepository()..result = pending.future;
    final viewModel = _viewModel(repository);
    final load = viewModel.load();

    await tester.pumpWidget(_timeline(viewModel));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(const []);
    await load;
    await tester.pump();
    expect(find.text('No recordings in this time window.'), findsOneWidget);

    repository.result = Future.error(StateError('offline'));
    await viewModel.refresh();
    await tester.pump();
    expect(find.text('Unable to load recording timeline.'), findsOneWidget);
  });

  testWidgets('remains usable on a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = _viewModel(_TimelineRepository());
    await viewModel.load();

    await tester.pumpWidget(_timeline(viewModel));

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.text('Today').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the view toggle usable in a narrow toolbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = _viewModel(_TimelineRepository());

    await tester.pumpWidget(_library(viewModel));

    expect(find.text('Grid').hitTestable(), findsOneWidget);
    expect(find.text('Timeline').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

RecordingTimelineViewModel _viewModel(_TimelineRepository repository) =>
    RecordingTimelineViewModel(
      repository,
      now: () => DateTime(2026, 10, 18, 12),
    );

Widget _library(RecordingTimelineViewModel viewModel) => MaterialApp(
  home: Scaffold(
    body: RecordingLibrary(
      recordings: const [],
      onRefresh: () async {},
      onLoadMore: () async {},
      onSetExpiry: (_, _) async {},
      hasMore: false,
      loadingMore: false,
      updatingExpiry: false,
      cameras: _cameras,
      timeline: viewModel,
    ),
  ),
);

Widget _timeline(RecordingTimelineViewModel viewModel) => MaterialApp(
  home: Scaffold(
    body: RecordingTimelineWidget(
      viewModel: viewModel,
      cameras: _cameras,
      onSetExpiry: (_) async => true,
    ),
  ),
);

class _TimelineRepository extends RecordingRepository {
  _TimelineRepository() : super(ApiClient());

  Future<List<RecordingTimelineInterval>> result = Future.value(const []);
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
    return result;
  }

  @override
  Future<Recording> find(String id) async {
    selectedIds.add(id);
    return Recording(
      id: id,
      cameraId: 'front-door',
      startTime: DateTime(2026, 10, 18, 12),
      endTime: DateTime(2026, 10, 18, 12, 5),
      durationMs: 300000,
      container: 'mp4',
      playbackUrl: '/$id.mp4',
    );
  }
}

RecordingTimelineInterval _interval(
  String id, {
  DateTime? start,
  DateTime? end,
}) => RecordingTimelineInterval(
  recordingId: id,
  cameraId: 'front-door',
  startTime: start ?? DateTime(2026, 10, 18, 12),
  endTime: end ?? DateTime(2026, 10, 18, 12, 5),
);

const _cameras = [
  Camera(
    id: 'front-door',
    name: 'Front Door',
    enabled: true,
    connection: CameraConnection(
      host: 'front.local',
      port: 554,
      mainStream: '/stream',
    ),
    recording: CameraRecordingConfig(
      enabled: true,
      mode: 'continuous',
      preEventSeconds: 5,
      postEventSeconds: 15,
    ),
    motion: CameraMotionConfig(
      enabled: false,
      stream: 'sub',
      fps: 5,
      sensitivity: 0.65,
    ),
  ),
  Camera(
    id: 'garage',
    name: 'Garage',
    enabled: false,
    connection: CameraConnection(
      host: 'garage.local',
      port: 554,
      mainStream: '/stream',
    ),
    recording: CameraRecordingConfig(
      enabled: true,
      mode: 'continuous',
      preEventSeconds: 5,
      postEventSeconds: 15,
    ),
    motion: CameraMotionConfig(
      enabled: false,
      stream: 'sub',
      fps: 5,
      sensitivity: 0.65,
    ),
  ),
];
