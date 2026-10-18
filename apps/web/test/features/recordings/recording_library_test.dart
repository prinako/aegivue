@TestOn('browser')
library;

import 'dart:async';

import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_card.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builds only visible recording cards', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recordings = List.generate(
      100,
      (index) => Recording(
        id: 'recording-$index',
        cameraId: 'camera-$index',
        startTime: DateTime.utc(2026, 10, 1),
        container: 'mp4',
        playbackUrl: '/recording-$index.mp4',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingLibrary(
            recordings: recordings,
            onRefresh: () async {},
            onLoadMore: () async {},
            onSetExpiry: (_, _) async {},
            hasMore: false,
            loadingMore: false,
            updatingExpiry: false,
          ),
        ),
      ),
    );

    expect(find.byType(RecordingCard), findsWidgets);
    expect(find.byType(RecordingCard).evaluate().length, lessThan(20));
  });

  testWidgets('keeps the date filter visible while the recording grid scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recordings = List.generate(
      100,
      (index) => Recording(
        id: 'recording-$index',
        cameraId: 'camera-$index',
        startTime: DateTime.utc(2026, 10, 1),
        container: 'mp4',
        playbackUrl: '/recording-$index.mp4',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingLibrary(
            recordings: recordings,
            onRefresh: () async {},
            onLoadMore: () async {},
            onSetExpiry: (_, _) async {},
            hasMore: false,
            loadingMore: false,
            updatingExpiry: false,
          ),
        ),
      ),
    );

    expect(find.text('Filter by date'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pump();

    expect(find.text('Filter by date'), findsOneWidget);
  });

  testWidgets('requests one next page while a near-bottom load is pending', (
    tester,
  ) async {
    final pending = Completer<void>();
    var loadMoreCalls = 0;
    final recordings = List.generate(
      30,
      (index) => Recording(
        id: 'recording-$index',
        cameraId: 'camera-$index',
        startTime: DateTime.utc(2026, 10, 1),
        container: 'mp4',
        playbackUrl: '/recording-$index.mp4',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingLibrary(
            recordings: recordings,
            onRefresh: () async {},
            onLoadMore: () {
              loadMoreCalls++;
              return pending.future;
            },
            onSetExpiry: (_, _) async {},
            hasMore: true,
            loadingMore: false,
            updatingExpiry: false,
          ),
        ),
      ),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -10000));
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
    await tester.pump();

    expect(loadMoreCalls, 1);
    pending.complete();
  });

  testWidgets('shows the empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingLibrary(
            recordings: const [],
            onRefresh: () async {},
            onLoadMore: () async {},
            onSetExpiry: (_, _) async {},
            hasMore: false,
            loadingMore: false,
            updatingExpiry: false,
          ),
        ),
      ),
    );

    expect(find.text('No finalized recordings yet.'), findsOneWidget);
    expect(find.text('Filter by date'), findsOneWidget);
  });

  testWidgets('applies the date range from the filter dialog', (tester) async {
    final from = DateTime(2026, 10, 17);
    final to = DateTime(2026, 10, 17, 23, 59, 59, 999, 999);
    DateTime? appliedFrom;
    DateTime? appliedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingLibrary(
            recordings: const [],
            onRefresh: () async {},
            onLoadMore: () async {},
            onSetExpiry: (_, _) async {},
            hasMore: false,
            loadingMore: false,
            updatingExpiry: false,
            filterFrom: from,
            filterTo: to,
            onApplyDateFilter: ({from, to}) async {
              appliedFrom = from;
              appliedTo = to;
            },
          ),
        ),
      ),
    );

    expect(find.text('17 Oct 2026 – 17 Oct 2026'), findsOneWidget);
    await tester.tap(find.text('17 Oct 2026 – 17 Oct 2026'));
    await tester.pumpAndSettle();

    expect(find.text('Filter recordings'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recording-filter-from-date')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('recording-filter-to-time')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(appliedFrom, from);
    expect(appliedTo, to);
  });

  testWidgets('clears an active date filter', (tester) async {
    var clearCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingLibrary(
            recordings: const [],
            onRefresh: () async {},
            onLoadMore: () async {},
            onSetExpiry: (_, _) async {},
            hasMore: false,
            loadingMore: false,
            updatingExpiry: false,
            filterFrom: DateTime(2026, 10, 17),
            onClearDateFilter: () async => clearCalls++,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Clear date filter'));
    await tester.pump();

    expect(clearCalls, 1);
  });

  testWidgets('shows a filtered empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingLibrary(
            recordings: const [],
            onRefresh: () async {},
            onLoadMore: () async {},
            onSetExpiry: (_, _) async {},
            hasMore: false,
            loadingMore: false,
            updatingExpiry: false,
            filterFrom: DateTime(2026, 10, 17),
          ),
        ),
      ),
    );

    expect(find.text('No recordings match this date filter.'), findsOneWidget);
  });

  testWidgets('shows the end-of-list message', (tester) async {
    final recording = Recording(
      id: 'recording-1',
      cameraId: 'front-door',
      startTime: DateTime.utc(2026, 10, 1),
      container: 'mp4',
      playbackUrl: '/recording.mp4',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingLibrary(
            recordings: [recording],
            onRefresh: () async {},
            onLoadMore: () async {},
            onSetExpiry: (_, _) async {},
            hasMore: false,
            loadingMore: false,
            updatingExpiry: false,
          ),
        ),
      ),
    );

    expect(find.text('All recordings loaded'), findsOneWidget);
  });

  testWidgets('uses responsive recording grid columns', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recordings = List.generate(
      20,
      (index) => Recording(
        id: 'recording-$index',
        cameraId: 'camera-$index',
        startTime: DateTime.utc(2026, 10, 1),
        container: 'mp4',
        playbackUrl: '/recording-$index.mp4',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingLibrary(
            recordings: recordings,
            onRefresh: () async {},
            onLoadMore: () async {},
            onSetExpiry: (_, _) async {},
            hasMore: false,
            loadingMore: false,
            updatingExpiry: false,
          ),
        ),
      ),
    );

    SliverGridDelegateWithFixedCrossAxisCount delegate() =>
        tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;

    expect(delegate().crossAxisCount, 2);

    tester.view.physicalSize = const Size(1280, 600);
    await tester.pump();

    expect(delegate().crossAxisCount, 4);
  });

  testWidgets('opens a recording in a dialog', (tester) async {
    final recording = Recording(
      id: 'recording-1',
      cameraId: 'front-door',
      startTime: DateTime.now(),
      container: 'mp4',
      playbackUrl: '/recording.mp4',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingLibrary(
            recordings: [recording],
            onRefresh: () async {},
            onLoadMore: () async {},
            onSetExpiry: (_, _) async {},
            hasMore: false,
            loadingMore: false,
            updatingExpiry: false,
          ),
        ),
      ),
    );

    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('front-door'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byTooltip('Close player'), findsOneWidget);
  });

  testWidgets('disables expiry changes for protected recordings', (
    tester,
  ) async {
    final recording = Recording(
      id: 'recording-1',
      cameraId: 'front-door',
      startTime: DateTime.now(),
      container: 'mp4',
      playbackUrl: '/recording.mp4',
      protected: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingLibrary(
            recordings: [recording],
            onRefresh: () async {},
            onLoadMore: () async {},
            onSetExpiry: (_, _) async {},
            hasMore: false,
            loadingMore: false,
            updatingExpiry: false,
          ),
        ),
      ),
    );

    await tester.tap(find.text('front-door'));
    await tester.pump();

    final button = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.event_available_outlined),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'opens the expiry picker when the current expiry is later today',
    (tester) async {
      final now = DateTime.now();
      final recording = Recording(
        id: 'recording-1',
        cameraId: 'front-door',
        startTime: now.subtract(const Duration(minutes: 5)),
        container: 'mp4',
        playbackUrl: '/recording.mp4',
        expiresAt: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordingLibrary(
              recordings: [recording],
              onRefresh: () async {},
              onLoadMore: () async {},
              onSetExpiry: (_, _) async {},
              hasMore: false,
              loadingMore: false,
              updatingExpiry: false,
            ),
          ),
        ),
      );

      await tester.tap(find.text('front-door'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Change expiry date'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Choose expiry date'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    },
  );
}
