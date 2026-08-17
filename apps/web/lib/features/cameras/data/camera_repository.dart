import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/core/api/api_endpoints.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';

class CameraRepository {
  const CameraRepository(this.api);
  final ApiClient api;

  Future<List<Camera>> list() async {
    final json = await api.getJson(ApiEndpoints.cameras) as List<Object?>;
    final cameras = json
        .map((item) => Camera.fromJson(item! as Map<String, Object?>))
        .toList(growable: false);
    return Future.wait(
      cameras.map((camera) async {
        if (!camera.enabled) return camera.withRuntimeState('disabled');
        try {
          final status =
              await api.getJson(ApiEndpoints.cameraStatus(camera.id))
                  as Map<String, Object?>;
          return camera.withRuntimeState(status['state']! as String);
        } catch (_) {
          return camera.withRuntimeState('offline');
        }
      }),
    );
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
