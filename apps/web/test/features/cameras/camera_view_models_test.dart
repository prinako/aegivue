import 'dart:async';

import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/view_models/camera_editor_view_model.dart';
import 'package:aegivue/features/cameras/presentation/view_models/camera_list_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CameraListViewModel', () {
    test('exposes loading before the initial request completes', () async {
      final pending = Completer<List<Camera>>();
      final viewModel = CameraListViewModel(
        _FakeCameraRepository(listResult: pending.future),
      );

      final load = viewModel.load();

      expect(viewModel.loading, isTrue);
      expect(viewModel.loaded, isFalse);
      pending.complete([_camera(id: 'front-door', name: 'Front Door')]);
      await load;
      expect(viewModel.loading, isFalse);
      expect(viewModel.loaded, isTrue);
    });

    test('exposes a successful initial load as immutable items', () async {
      final viewModel = CameraListViewModel(
        _FakeCameraRepository(
          listResult: Future.value([
            _camera(id: 'yard', name: 'Yard'),
            _camera(id: 'back-door', name: 'Back Door'),
          ]),
        ),
      );

      await viewModel.load();

      expect(viewModel.items.map((camera) => camera.id), ['yard', 'back-door']);
      expect(() => viewModel.items.add(_camera()), throwsUnsupportedError);
      expect(viewModel.error, isNull);
    });

    test(
      'exposes an initial load failure without marking data loaded',
      () async {
        final failure = StateError('offline');
        final viewModel = CameraListViewModel(
          _FakeCameraRepository(listResult: Future.error(failure)),
        );

        await viewModel.load();

        expect(viewModel.loading, isFalse);
        expect(viewModel.loaded, isFalse);
        expect(viewModel.error, same(failure));
      },
    );

    test('refresh preserves loaded items when the request fails', () async {
      final repository = _FakeCameraRepository(
        listResult: Future.value([_camera()]),
      );
      final viewModel = CameraListViewModel(repository);
      await viewModel.load();
      final failure = StateError('offline');
      repository.listResult = Future.error(failure);

      await viewModel.refresh();

      expect(viewModel.items.single.id, 'camera-1');
      expect(viewModel.loaded, isTrue);
      expect(viewModel.error, same(failure));
    });

    test(
      'upsert replaces a camera while preserving its runtime state',
      () async {
        final viewModel = CameraListViewModel(
          _FakeCameraRepository(
            listResult: Future.value([_camera(runtimeState: 'online')]),
          ),
        );
        await viewModel.load();

        viewModel.upsert(_camera(name: 'Updated'));

        expect(viewModel.items.single.name, 'Updated');
        expect(viewModel.items.single.runtimeState, 'online');
      },
    );
  });

  group('CameraEditorViewModel', () {
    test('creates a camera and exposes the saved result', () async {
      final saved = _camera(name: 'Saved camera');
      final repository = _FakeCameraRepository(
        listResult: Future.value(const []),
        createResult: Future.value(saved),
      );
      final viewModel = CameraEditorViewModel(repository);

      final result = await viewModel.save(_configuration());

      expect(result, isTrue);
      expect(viewModel.savedCamera, same(saved));
      expect(viewModel.saving, isFalse);
      expect(viewModel.error, isNull);
    });

    test('updates an existing camera', () async {
      final saved = _camera(name: 'Updated camera');
      final repository = _FakeCameraRepository(
        listResult: Future.value(const []),
        updateResult: Future.value(saved),
      );
      final viewModel = CameraEditorViewModel(repository, editing: true);

      final result = await viewModel.save(_configuration());

      expect(result, isTrue);
      expect(viewModel.savedCamera, same(saved));
      expect(repository.updateCalls, 1);
      expect(repository.createCalls, 0);
    });

    test('exposes save failure for the view', () async {
      final failure = StateError('save failed');
      final viewModel = CameraEditorViewModel(
        _FakeCameraRepository(
          listResult: Future.value(const []),
          createResult: Future.error(failure),
        ),
      );

      final result = await viewModel.save(_configuration());

      expect(result, isFalse);
      expect(viewModel.saving, isFalse);
      expect(viewModel.error, same(failure));
      expect(viewModel.savedCamera, isNull);
    });
  });
}

class _FakeCameraRepository extends CameraRepository {
  _FakeCameraRepository({
    required this.listResult,
    this.createResult,
    this.updateResult,
  }) : super(ApiClient());

  Future<List<Camera>> listResult;
  Future<Camera>? createResult;
  Future<Camera>? updateResult;
  int createCalls = 0;
  int updateCalls = 0;

  @override
  Future<List<Camera>> list() => listResult;

  @override
  Future<Camera> create(CameraConfiguration configuration) {
    createCalls++;
    return createResult!;
  }

  @override
  Future<Camera> update(CameraConfiguration configuration) {
    updateCalls++;
    return updateResult!;
  }
}

Camera _camera({
  String id = 'camera-1',
  String name = 'Camera',
  String runtimeState = 'offline',
}) => Camera(
  id: id,
  name: name,
  enabled: true,
  connection: const CameraConnection(
    host: '192.168.1.10',
    port: 554,
    mainStream: '/main',
  ),
  recording: const CameraRecordingConfig(
    enabled: true,
    mode: 'continuous',
    preEventSeconds: 5,
    postEventSeconds: 15,
  ),
  motion: const CameraMotionConfig(
    enabled: false,
    stream: 'main',
    fps: 5,
    sensitivity: 0.65,
  ),
  runtimeState: runtimeState,
);

CameraConfiguration _configuration() => const CameraConfiguration(
  id: 'camera-1',
  name: 'Camera',
  enabled: true,
  host: '192.168.1.10',
  port: 554,
  mainStream: '/main',
  recordingEnabled: true,
  recordingMode: 'continuous',
  preEventSeconds: 5,
  postEventSeconds: 15,
  motionEnabled: false,
  motionStream: 'main',
  motionFps: 5,
  motionSensitivity: 0.65,
);
