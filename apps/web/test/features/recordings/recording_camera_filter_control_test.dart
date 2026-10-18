@TestOn('browser')
library;

import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/domain/camera_connection.dart';
import 'package:aegivue/features/cameras/domain/camera_motion_config.dart';
import 'package:aegivue/features/cameras/domain/camera_recording_config.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_camera_filter_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects one camera by name', (tester) async {
    Set<String>? applied;
    await tester.pumpWidget(
      _app(
        RecordingCameraFilterControl(
          cameras: [
            _camera(id: 'front-door', name: 'Front Door'),
            _camera(id: 'garage', name: 'Garage'),
          ],
          selectedCameraIds: const {},
          loading: false,
          onApply: (cameraIds) async => applied = cameraIds,
          onClear: () async {},
        ),
      ),
    );

    await tester.tap(find.text('All cameras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Front Door'));
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(applied, {'front-door'});
  });

  testWidgets('selects multiple cameras in one dialog', (tester) async {
    Set<String>? applied;
    await tester.pumpWidget(
      _app(
        RecordingCameraFilterControl(
          cameras: [
            _camera(id: 'front-door', name: 'Front Door'),
            _camera(id: 'garage', name: 'Garage'),
            _camera(id: 'yard', name: 'Yard'),
          ],
          selectedCameraIds: const {},
          loading: false,
          onApply: (cameraIds) async => applied = cameraIds,
          onClear: () async {},
        ),
      ),
    );

    await tester.tap(find.text('All cameras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Front Door'));
    await tester.tap(find.text('Garage'));
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(applied, {'front-door', 'garage'});
  });

  testWidgets('shows the selected camera count for multiple cameras', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        RecordingCameraFilterControl(
          cameras: [
            _camera(id: 'front-door', name: 'Front Door'),
            _camera(id: 'garage', name: 'Garage'),
            _camera(id: 'yard', name: 'Yard'),
          ],
          selectedCameraIds: const {'front-door', 'garage'},
          loading: false,
          onApply: (_) async {},
          onClear: () async {},
        ),
      ),
    );

    expect(find.text('2 cameras'), findsOneWidget);
  });

  testWidgets('normalizes Select all and Clear to no camera restriction', (
    tester,
  ) async {
    var clearCalls = 0;
    await tester.pumpWidget(
      _app(
        RecordingCameraFilterControl(
          cameras: [
            _camera(id: 'front-door', name: 'Front Door'),
            _camera(id: 'garage', name: 'Garage'),
          ],
          selectedCameraIds: const {'front-door'},
          loading: false,
          onApply: (_) async {},
          onClear: () async => clearCalls++,
        ),
      ),
    );

    await tester.tap(find.text('Front Door'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(clearCalls, 1);

    await tester.tap(find.text('Front Door'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(clearCalls, 2);
  });

  testWidgets('handles loading, empty, and failed camera lists', (
    tester,
  ) async {
    Future<void> pump({required bool loading, Object? error}) =>
        tester.pumpWidget(
          _app(
            RecordingCameraFilterControl(
              cameras: const [],
              selectedCameraIds: const {},
              loading: loading,
              error: error,
              onApply: (_) async {},
              onClear: () async {},
            ),
          ),
        );

    await pump(loading: true);
    expect(find.text('Loading cameras'), findsOneWidget);

    await pump(loading: false);
    expect(find.text('No cameras'), findsOneWidget);

    await pump(loading: false, error: StateError('offline'));
    expect(find.text('Camera filter unavailable'), findsOneWidget);
  });

  testWidgets('keeps a selected camera visible when it is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        RecordingCameraFilterControl(
          cameras: const [],
          selectedCameraIds: const {'retired-camera'},
          loading: false,
          onApply: (_) async {},
          onClear: () async {},
        ),
      ),
    );

    expect(find.text('retired-camera'), findsOneWidget);
    await tester.tap(find.text('retired-camera'));
    await tester.pumpAndSettle();
    expect(find.text('retired-camera (unavailable)'), findsOneWidget);
  });
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

const _connection = CameraConnection(
  host: 'camera.local',
  port: 554,
  mainStream: '/stream',
);
const _recording = CameraRecordingConfig(
  enabled: true,
  mode: 'continuous',
  preEventSeconds: 5,
  postEventSeconds: 15,
);
const _motion = CameraMotionConfig(
  enabled: false,
  stream: 'sub',
  fps: 5,
  sensitivity: 0.65,
);

Camera _camera({required String id, required String name}) => Camera(
  id: id,
  name: name,
  enabled: true,
  connection: _connection,
  recording: _recording,
  motion: _motion,
);
