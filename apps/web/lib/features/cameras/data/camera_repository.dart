import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/core/api/api_endpoints.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/domain/camera_configuration.dart';

class CameraRepository {
  const CameraRepository(this.api);
  static const int _statusBatchSize = 4;

  final ApiClient api;

  Future<List<Camera>> list() async {
    final json = await api.getJson(ApiEndpoints.cameras) as List<Object?>;
    return json
        .map((item) => Camera.fromJson(item! as Map<String, Object?>))
        .map(
          (camera) =>
              camera.enabled ? camera : camera.withRuntimeState('disabled'),
        )
        .toList(growable: false);
  }

  Stream<List<Camera>> runtimeStateUpdates(List<Camera> cameras) async* {
    final current = [...cameras];
    final enabledIndexes = <int>[
      for (var index = 0; index < current.length; index++)
        if (current[index].enabled) index,
    ];
    for (
      var offset = 0;
      offset < enabledIndexes.length;
      offset += _statusBatchSize
    ) {
      final end = (offset + _statusBatchSize).clamp(0, enabledIndexes.length);
      final batch = enabledIndexes.sublist(offset, end);
      final updates = await Future.wait(
        batch.map((index) => _loadRuntimeState(current[index])),
      );
      for (var index = 0; index < batch.length; index++) {
        current[batch[index]] = updates[index];
      }
      yield List<Camera>.unmodifiable(current);
    }
  }

  Future<Camera> _loadRuntimeState(Camera camera) async {
    try {
      final status =
          await api.getJson(ApiEndpoints.cameraStatus(camera.id))
              as Map<String, Object?>;
      return camera.withRuntimeState(status['state']! as String);
    } catch (_) {
      return camera.withRuntimeState('unavailable');
    }
  }

  Future<Camera> create(CameraConfiguration configuration) async {
    final json = await api.postJson(
      ApiEndpoints.cameras,
      data: configuration.toJson(includeId: true),
    );
    return Camera.fromJson(json! as Map<String, Object?>);
  }

  Future<Camera> update(CameraConfiguration configuration) async {
    final json = await api.patchJson(
      ApiEndpoints.camera(configuration.id),
      data: configuration.toJson(includeId: false),
    );
    return Camera.fromJson(json! as Map<String, Object?>);
  }
}
