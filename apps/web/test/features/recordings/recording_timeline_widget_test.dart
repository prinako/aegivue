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
import 'package:aegivue/features/recordings/presentation/models/recording_playback.dart';
import 'package:aegivue/features/recordings/presentation/view_models/recording_timeline_view_model.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_library.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_header_actions.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_player.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_timeline_widget.dart';
import 'package:aegivue/features/recordings/presentation/widgets/selected_recording_card.dart';
import 'package:flutter/gestures.dart';
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

  testWidgets('shows an empty playback workspace before selection', (
    tester,
  ) async {
    final viewModel = _viewModel(_TimelineRepository());
    await viewModel.load();

    await tester.pumpWidget(_timeline(viewModel));

    expect(find.text('Select footage to begin playback.'), findsOneWidget);
    expect(find.byType(RecordingPlayer), findsNothing);
  });

  testWidgets('shows camera rows and positions intervals from timestamps', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([
        _interval(
          'recording-1',
          start: DateTime(2026, 10, 18, 12, 15),
          end: DateTime(2026, 10, 18, 12, 30),
        ),
      ]);
    final viewModel = _viewModel(repository);
    await viewModel.load();
    viewModel.setZoom(RecordingTimelineZoom.oneHour);

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
    expect(segment.width, closeTo(track.width * 0.25, 1));
  });

  testWidgets('keeps overlapping intervals individually clickable', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([
        _interval(
          'recording-1',
          start: DateTime(2026, 10, 18, 12, 15),
          end: DateTime(2026, 10, 18, 12, 45),
        ),
        _interval(
          'recording-2',
          start: DateTime(2026, 10, 18, 12, 30),
          end: DateTime(2026, 10, 18, 12, 55),
        ),
      ]);
    final viewModel = _viewModel(repository);
    await viewModel.load();
    viewModel.setZoom(RecordingTimelineZoom.oneHour);

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

  testWidgets('merges overlapping and adjacent intervals in coverage mode', (
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
        _interval(
          'recording-3',
          start: DateTime(2026, 10, 18, 7, 30),
          end: DateTime(2026, 10, 18, 8),
        ),
        _interval(
          'recording-4',
          start: DateTime(2026, 10, 18, 8, 1),
          end: DateTime(2026, 10, 18, 9),
        ),
      ]);
    final viewModel = _viewModel(repository);
    await viewModel.load();

    await tester.pumpWidget(_timeline(viewModel));

    expect(
      find.byKey(const ValueKey('timeline-coverage-front-door')),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const ValueKey('timeline-segment-recording-1')),
      findsNothing,
    );
  });

  testWidgets('selects the original file from a coverage interval', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([_interval('recording-1')]);
    final viewModel = _viewModel(repository);
    await viewModel.load();
    await tester.pumpWidget(_timeline(viewModel));

    await tester.tap(
      find.byKey(const ValueKey('timeline-coverage-front-door')),
    );
    await tester.pumpAndSettle();

    expect(repository.selectedIds, ['recording-1']);
    expect(find.byType(SelectedRecordingCard), findsOneWidget);
  });

  testWidgets('uses zoom-specific dynamic time ticks', (tester) async {
    final viewModel = _viewModel(_TimelineRepository());
    await viewModel.load();
    await tester.pumpWidget(_timeline(viewModel));

    expect(find.byKey(const ValueKey('timeline-tick-04:00')), findsOneWidget);

    viewModel.setZoom(RecordingTimelineZoom.sixHours);
    await tester.pump();
    expect(find.byKey(const ValueKey('timeline-tick-13:00')), findsOneWidget);

    viewModel.setZoom(RecordingTimelineZoom.oneHour);
    await tester.pump();
    expect(find.byKey(const ValueKey('timeline-tick-12:15')), findsOneWidget);
  });

  testWidgets('shows the current-time indicator only for today', (
    tester,
  ) async {
    final viewModel = _viewModel(_TimelineRepository());
    await viewModel.load();
    await tester.pumpWidget(_timeline(viewModel));

    expect(find.byKey(const ValueKey('timeline-current-time')), findsOneWidget);

    await viewModel.previousDay();
    await tester.pump();
    expect(find.byKey(const ValueKey('timeline-current-time')), findsNothing);
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
    expect(track.width, lessThan(800));
    expect(find.byTooltip('Previous window'), findsOneWidget);
  });

  testWidgets('centers zoom on the selected recording timestamp', (
    tester,
  ) async {
    final interval = _interval(
      'recording-1',
      start: DateTime(2026, 10, 18, 18),
      end: DateTime(2026, 10, 18, 18, 5),
    );
    final repository = _TimelineRepository()..result = Future.value([interval]);
    final viewModel = _viewModel(repository);
    await viewModel.load();
    await viewModel.select(interval);
    await tester.pumpWidget(_timeline(viewModel));

    viewModel.setZoom(RecordingTimelineZoom.sixHours);
    await tester.pumpAndSettle();

    expect(viewModel.windowStart, DateTime(2026, 10, 18, 18));
    expect(viewModel.windowEnd, DateTime(2026, 10, 19));
    expect(
      find.byKey(const ValueKey('timeline-horizontal-scroll')),
      findsNothing,
    );
  });

  testWidgets('selects a segment and shows one playback card', (tester) async {
    final repository = _TimelineRepository()
      ..result = Future.value([_interval('recording-1')]);
    final viewModel = _viewModel(repository);
    await viewModel.load();
    viewModel.setZoom(RecordingTimelineZoom.oneHour);

    await tester.pumpWidget(_timeline(viewModel));
    await tester.tap(
      find.byKey(const ValueKey('timeline-segment-recording-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Front Door'), findsWidgets);
    expect(find.byType(SelectedRecordingCard), findsOneWidget);
    expect(find.byType(RecordingPlayer), findsOneWidget);
    expect(repository.selectedIds, ['recording-1']);
  });

  testWidgets('segment click seeks to its represented timestamp', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([
        _interval(
          'recording-1',
          start: DateTime(2026, 10, 18, 12),
          end: DateTime(2026, 10, 18, 12, 5),
        ),
      ]);
    final viewModel = _viewModel(repository);
    await viewModel.load();
    viewModel.setZoom(RecordingTimelineZoom.oneHour);
    await tester.pumpWidget(_timeline(viewModel));

    final segment = find.byKey(const ValueKey('timeline-segment-recording-1'));
    final rect = tester.getRect(segment);
    await tester.tapAt(Offset(rect.left + rect.width * 0.6, rect.center.dy));
    await tester.pumpAndSettle();

    expect(find.text('Shared time 12:03:00'), findsOneWidget);
  });

  testWidgets('horizontal drag over a recording does not trigger a tap', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([
        _interval(
          'recording-1',
          start: DateTime(2026, 10, 18, 12),
          end: DateTime(2026, 10, 18, 13),
        ),
      ]);
    final viewModel = _viewModel(repository);
    await viewModel.load(cameraIds: {'front-door'});
    viewModel.setZoom(RecordingTimelineZoom.oneHour);
    await tester.pumpWidget(_timeline(viewModel));

    final track = tester.getRect(
      find.byKey(const ValueKey('timeline-track-front-door')),
    );
    final gesture = await tester.startGesture(
      Offset(track.left + track.width * 0.2, track.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(
      Offset(track.left + track.width * 0.4, track.center.dy),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('timeline-scrub-preview')),
      findsOneWidget,
    );
    expect(repository.selectedIds, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(repository.selectedIds, ['recording-1']);
    expect(viewModel.sharedTimestamp, DateTime(2026, 10, 18, 12, 24).toUtc());
  });

  testWidgets('previews a mouse scrub and seeks only when released', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([
        _interval(
          'recording-1',
          start: DateTime(2026, 10, 18, 12),
          end: DateTime(2026, 10, 18, 13),
        ),
      ]);
    final viewModel = _viewModel(repository);
    await viewModel.load(cameraIds: {'front-door'});
    viewModel.setZoom(RecordingTimelineZoom.oneHour);
    await tester.pumpWidget(_timeline(viewModel));
    final track = tester.getRect(
      find.byKey(const ValueKey('timeline-track-front-door')),
    );

    final gesture = await tester.startGesture(
      Offset(track.left + track.width * 0.1, track.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(
      Offset(track.left + track.width * 0.5, track.center.dy),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('timeline-scrub-preview')),
      findsOneWidget,
    );
    expect(find.text('12:30:00'), findsOneWidget);
    expect(repository.selectedIds, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('timeline-scrub-preview')), findsNothing);
    expect(viewModel.sharedTimestamp, DateTime(2026, 10, 18, 12, 30).toUtc());
    expect(repository.selectedIds, ['recording-1']);
  });

  testWidgets('clamps touch scrubbing and seeks every selected camera once', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([
        _interval(
          'front-recording',
          cameraId: 'front-door',
          start: DateTime(2026, 10, 18, 12),
          end: DateTime(2026, 10, 18, 13),
        ),
        _interval(
          'garage-recording',
          cameraId: 'garage',
          start: DateTime(2026, 10, 18, 12),
          end: DateTime(2026, 10, 18, 13),
        ),
      ])
      ..findOverride = (id) => Future.value(
        _recordingFor(id, id.startsWith('front') ? 'front-door' : 'garage'),
      );
    final viewModel = _viewModel(repository);
    await viewModel.load(cameraIds: {'front-door', 'garage'});
    viewModel.setZoom(RecordingTimelineZoom.oneHour);
    await tester.pumpWidget(_timeline(viewModel));
    final track = tester.getRect(
      find.byKey(const ValueKey('timeline-track-front-door')),
    );

    final gesture = await tester.startGesture(
      Offset(track.center.dx, track.center.dy),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveTo(Offset(track.left - 80, track.center.dy));
    await tester.pump();

    expect(find.text('12:00:00'), findsOneWidget);
    expect(repository.selectedIds, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(viewModel.sharedTimestamp, DateTime(2026, 10, 18, 12).toUtc());
    expect(
      repository.selectedIds,
      unorderedEquals(['front-recording', 'garage-recording']),
    );
  });

  testWidgets('positions the playback playhead consistently across zooms', (
    tester,
  ) async {
    final interval = _interval('recording-1');
    final repository = _TimelineRepository()..result = Future.value([interval]);
    final viewModel = _viewModel(repository);
    await viewModel.load();
    await viewModel.select(interval);
    viewModel.handlePlaybackEvent(
      interval.recordingId,
      const RecordingPlaybackEvent(
        phase: RecordingPlaybackPhase.playing,
        position: Duration(minutes: 3),
      ),
    );
    await tester.pumpWidget(_timeline(viewModel));

    final dayLeft = tester
        .widget<Positioned>(
          find.byKey(const ValueKey('timeline-playback-playhead')),
        )
        .left!;
    viewModel.setZoom(RecordingTimelineZoom.sixHours);
    await tester.pump();
    final zoomedLeft = tester
        .widget<Positioned>(
          find.byKey(const ValueKey('timeline-playback-playhead')),
        )
        .left!;

    final trackWidth = tester
        .getSize(find.byKey(const ValueKey('timeline-track-front-door')))
        .width;
    expect(dayLeft, closeTo(trackWidth * (12 * 60 + 3) / (24 * 60), 0.01));
    expect(zoomedLeft, closeTo(trackWidth * 3 / (6 * 60), 0.01));
  });

  testWidgets('reports a clicked gap without selecting unrelated footage', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([_interval('recording-1')]);
    final viewModel = _viewModel(repository);
    await viewModel.load();
    await tester.pumpWidget(_timeline(viewModel));
    final gap = find.byKey(const ValueKey('timeline-gap-front-door'));
    final rect = tester.getRect(gap);

    await tester.tapAt(Offset(rect.left + 10, rect.center.dy));
    await tester.pump();

    expect(find.text('No footage'), findsNWidgets(2));
    expect(repository.selectedIds, isEmpty);
    expect(find.byType(RecordingPlayer), findsNothing);
  });

  testWidgets('shows playback state and closes the integrated player', (
    tester,
  ) async {
    final interval = _interval('recording-1');
    final repository = _TimelineRepository()..result = Future.value([interval]);
    final viewModel = _viewModel(repository);
    await viewModel.load();
    await viewModel.select(interval);
    await tester.pumpWidget(_timeline(viewModel));

    expect(find.textContaining('Ready'), findsOneWidget);
    viewModel.handlePlaybackEvent(
      interval.recordingId,
      const RecordingPlaybackEvent(
        phase: RecordingPlaybackPhase.paused,
        position: Duration(seconds: 20),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Paused'), findsOneWidget);

    await tester.tap(find.byTooltip('Close player'));
    await tester.pump();
    expect(find.byType(RecordingPlayer), findsNothing);
    expect(find.text('Select footage to begin playback.'), findsOneWidget);
  });

  testWidgets('shows recording-detail loading and error states', (
    tester,
  ) async {
    final detail = Completer<Recording>();
    final repository = _TimelineRepository()
      ..result = Future.value([_interval('recording-1')])
      ..findOverride = (_) => detail.future;
    final viewModel = _viewModel(repository);
    await viewModel.load();
    await tester.pumpWidget(_timeline(viewModel));

    await tester.tap(
      find.byKey(const ValueKey('timeline-coverage-front-door')),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    detail.completeError(StateError('missing'));
    await tester.pumpAndSettle();
    expect(find.text('Bad state: missing'), findsOneWidget);
  });

  testWidgets('navigates fixed timeline windows without another request', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([
        _interval(
          'recording-2',
          start: DateTime(2026, 10, 18, 13),
          end: DateTime(2026, 10, 18, 13, 5),
        ),
        _interval(
          'recording-1',
          start: DateTime(2026, 10, 18, 12),
          end: DateTime(2026, 10, 18, 12, 5),
        ),
      ]);
    final viewModel = _viewModel(repository);
    await viewModel.load();
    await viewModel.select(repository.resultIntervals.last);
    viewModel.setZoom(RecordingTimelineZoom.oneHour);
    await tester.pumpWidget(_timeline(viewModel));

    expect(viewModel.windowStart, DateTime(2026, 10, 18, 12));
    await tester.tap(find.byTooltip('Next window'));
    await tester.pump();

    expect(viewModel.windowStart, DateTime(2026, 10, 18, 13));
    expect(repository.requests, hasLength(1));
    expect(viewModel.selectedRecording?.id, 'recording-1');
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
    final interval = _interval('recording-1');
    final repository = _TimelineRepository()..result = Future.value([interval]);
    final viewModel = _viewModel(repository);
    await viewModel.load();
    await viewModel.select(interval);

    await tester.pumpWidget(_timeline(viewModel));

    expect(
      find.byKey(const ValueKey('timeline-horizontal-scroll')),
      findsNothing,
    );
    expect(find.text('Today').hitTestable(), findsOneWidget);
    expect(find.byType(RecordingPlayer), findsOneWidget);
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

  testWidgets('uses a fixed-width timeline without horizontal scrolling', (
    tester,
  ) async {
    final viewModel = _viewModel(_TimelineRepository());
    await viewModel.load();
    viewModel.setZoom(RecordingTimelineZoom.oneHour);

    await tester.pumpWidget(_timeline(viewModel));

    expect(
      find.byKey(const ValueKey('timeline-horizontal-scroll')),
      findsNothing,
    );
    final track = tester.getRect(
      find.byKey(const ValueKey('timeline-track-front-door')),
    );
    expect(track.right, lessThanOrEqualTo(800));
    expect(find.byTooltip('Previous window'), findsOneWidget);
    expect(find.byTooltip('Next window'), findsOneWidget);
  });

  testWidgets('opens synchronized players for two cameras at one timestamp', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([
        _interval(
          'front-recording',
          cameraId: 'front-door',
          start: DateTime(2026, 10, 18, 12),
          end: DateTime(2026, 10, 18, 12, 5),
        ),
        _interval(
          'garage-recording',
          cameraId: 'garage',
          start: DateTime(2026, 10, 18, 11, 58),
          end: DateTime(2026, 10, 18, 12, 5),
        ),
      ])
      ..findOverride = (id) => Future.value(
        _recordingFor(id, id.startsWith('front') ? 'front-door' : 'garage'),
      );
    final viewModel = _viewModel(repository);
    await viewModel.load(cameraIds: {'front-door', 'garage'});
    await tester.pumpWidget(_timeline(viewModel));

    await tester.tap(
      find.byKey(const ValueKey('timeline-coverage-front-door')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RecordingPlayer), findsNWidgets(2));
    expect(find.text('Front Door'), findsWidgets);
    expect(find.text('Garage'), findsWidgets);
    expect(find.byTooltip('Play all cameras'), findsOneWidget);
  });

  testWidgets('replaces an ended player with the contiguous segment', (
    tester,
  ) async {
    final repository = _TimelineRepository()
      ..result = Future.value([
        _interval(
          'front-first',
          start: DateTime(2026, 10, 18, 12),
          end: DateTime(2026, 10, 18, 12, 5),
        ),
        _interval(
          'front-second',
          start: DateTime(2026, 10, 18, 12, 5),
          end: DateTime(2026, 10, 18, 12, 10),
        ),
      ]);
    final viewModel = _viewModel(repository);
    await viewModel.load(cameraIds: {'front-door'});
    await viewModel.seekTo(DateTime(2026, 10, 18, 12, 4));
    await tester.pumpWidget(_timeline(viewModel));
    viewModel.play();
    await tester.pump();

    viewModel.handleCameraPlaybackEvent(
      'front-door',
      'front-first',
      const RecordingPlaybackEvent(
        phase: RecordingPlaybackPhase.ended,
        position: Duration(minutes: 5),
        duration: Duration(minutes: 5),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player-/front-first.mp4')), findsNothing);
    expect(
      find.byKey(const ValueKey('player-/front-second.mp4')),
      findsOneWidget,
    );
    expect(find.byType(RecordingPlayer), findsOneWidget);
    expect(viewModel.playing, isTrue);
    viewModel.dispose();
  });

  testWidgets('toggles the visible shared play pause control', (tester) async {
    final repository = _TimelineRepository()
      ..result = Future.value([_interval('recording-1')]);
    final viewModel = _viewModel(repository);
    await viewModel.load(cameraIds: {'front-door'});
    await viewModel.seekTo(DateTime(2026, 10, 18, 12, 2));
    await tester.pumpWidget(_timeline(viewModel));

    await tester.tap(find.byTooltip('Play all cameras'));
    await tester.pump();
    expect(find.byTooltip('Pause all cameras'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause all cameras'));
    await tester.pump();
    expect(find.byTooltip('Play all cameras'), findsOneWidget);
    viewModel.dispose();
  });
}

RecordingTimelineViewModel _viewModel(_TimelineRepository repository) =>
    RecordingTimelineViewModel(
      repository,
      now: () => DateTime(2026, 10, 18, 12),
    );

Widget _library(RecordingTimelineViewModel viewModel) => MaterialApp(
  home: Scaffold(body: _LibraryHarness(viewModel: viewModel)),
);

Widget _timeline(RecordingTimelineViewModel viewModel) => MaterialApp(
  home: Scaffold(
    body: RecordingTimelineWidget(
      viewModel: viewModel,
      cameras: _cameras,
      onSetExpiry: (_) async => true,
      now: () => DateTime(2026, 10, 18, 12),
    ),
  ),
);

class _LibraryHarness extends StatefulWidget {
  const _LibraryHarness({required this.viewModel});
  final RecordingTimelineViewModel viewModel;

  @override
  State<_LibraryHarness> createState() => _LibraryHarnessState();
}

class _LibraryHarnessState extends State<_LibraryHarness> {
  RecordingLibraryView view = RecordingLibraryView.grid;

  Future<void> _select(RecordingLibraryView value) async {
    setState(() => view = value);
    if (value == RecordingLibraryView.timeline) {
      await widget.viewModel.load();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      RecordingHeaderActions(
        view: view,
        onSelectView: _select,
        filterFrom: null,
        filterTo: null,
        onApplyDateFilter: ({from, to}) async {},
        onClearDateFilter: () async {},
        cameras: _cameras,
        camerasLoading: false,
        cameraError: null,
        selectedCameraIds: const {},
        onApplyCameraFilter: (_) async {},
        onClearCameraFilter: () async {},
      ),
      Expanded(
        child: RecordingLibrary(
          view: view,
          recordings: const [],
          onRefresh: () async {},
          onLoadMore: () async {},
          onSetExpiry: (_, _) async {},
          hasMore: false,
          loadingMore: false,
          updatingExpiry: false,
          cameras: _cameras,
          timeline: widget.viewModel,
        ),
      ),
    ],
  );
}

class _TimelineRepository extends RecordingRepository {
  _TimelineRepository() : super(ApiClient());

  Future<List<RecordingTimelineInterval>> result = Future.value(const []);
  List<RecordingTimelineInterval> resultIntervals = const [];
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
    return result.then((items) {
      resultIntervals = items;
      return items;
    });
  }

  @override
  Future<Recording> find(String id) async {
    selectedIds.add(id);
    final override = findOverride;
    if (override != null) return override(id);
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
  String cameraId = 'front-door',
  DateTime? start,
  DateTime? end,
}) => RecordingTimelineInterval(
  recordingId: id,
  cameraId: cameraId,
  startTime: start ?? DateTime(2026, 10, 18, 12),
  endTime: end ?? DateTime(2026, 10, 18, 12, 5),
);

Recording _recordingFor(String id, String cameraId) => Recording(
  id: id,
  cameraId: cameraId,
  startTime: cameraId == 'garage'
      ? DateTime(2026, 10, 18, 11, 58)
      : DateTime(2026, 10, 18, 12),
  endTime: DateTime(2026, 10, 18, 12, 5),
  durationMs: cameraId == 'garage' ? 420000 : 300000,
  container: 'mp4',
  playbackUrl: '/$id.mp4',
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
