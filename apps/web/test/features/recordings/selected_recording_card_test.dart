@TestOn('browser')
library;

import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/widgets/selected_recording_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('omits expiry action when expiry changes are unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(_card(recording: _recording()));

    expect(find.byTooltip('Set expiry date'), findsNothing);
    expect(find.byTooltip('Download recording'), findsOneWidget);
    expect(find.byTooltip('Close player'), findsOneWidget);
  });

  testWidgets('disables expiry action for a protected recording', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(recording: _recording(protected: true), onSetExpiry: () {}),
    );

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Protected recordings cannot expire'),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Protection: Protected', findRichText: true), findsOne);
  });

  testWidgets('shows progress while an expiry update is pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(recording: _recording(), onSetExpiry: () {}, updatingExpiry: true),
    );

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Set expiry date'),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders available recording details', (tester) async {
    await tester.pumpWidget(
      _card(
        recording: _recording(
          videoCodec: 'h264',
          audioCodec: 'aac',
          width: 1920,
          height: 1080,
          fps: 29.97,
        ),
      ),
    );

    expect(find.text('Container: MP4', findRichText: true), findsOne);
    expect(find.text('Video: h264', findRichText: true), findsOne);
    expect(find.text('Audio: aac', findRichText: true), findsOne);
    expect(find.text('Resolution: 1920×1080', findRichText: true), findsOne);
    expect(find.text('FPS: 30.0', findRichText: true), findsOne);
    expect(
      find.text('Retention: Keep indefinitely', findRichText: true),
      findsOne,
    );
  });
}

Widget _card({
  required Recording recording,
  VoidCallback? onSetExpiry,
  bool updatingExpiry = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SelectedRecordingCard(
        recording: recording,
        onSetExpiry: onSetExpiry,
        onClose: () {},
        updatingExpiry: updatingExpiry,
      ),
    ),
  );
}

Recording _recording({
  bool protected = false,
  String? videoCodec,
  String? audioCodec,
  int? width,
  int? height,
  double? fps,
}) {
  return Recording(
    id: 'recording-1',
    cameraId: 'front-door',
    startTime: DateTime.utc(2026, 10, 17),
    container: 'mp4',
    playbackUrl: '/recording.mp4',
    protected: protected,
    videoCodec: videoCodec,
    audioCodec: audioCodec,
    width: width,
    height: height,
    fps: fps,
  );
}
