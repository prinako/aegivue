@TestOn('browser')
library;

import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      await tester.pump();
      await tester.tap(find.byTooltip('Change expiry date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose expiry date'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    },
  );
}
