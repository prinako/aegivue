import '../../../core/api_client.dart';
import '../domain/camera.dart';

class CameraRepository {
  const CameraRepository(this.api);
  final ApiClient api;
  Future<List<Camera>> list() async {
    final json = await api.getJson('/api/v1/cameras') as List<Object?>;
    final cameras = json
        .map((item) => Camera.fromJson(item! as Map<String, Object?>))
        .toList(growable: false);
    return Future.wait(
      cameras.map((camera) async {
        if (!camera.enabled) return camera.withRuntimeState('disabled');
        try {
          final status =
              await api.getJson('/api/v1/cameras/${camera.id}/status')
                  as Map<String, Object?>;
          return camera.withRuntimeState(status['state']! as String);
        } catch (_) {
          return camera.withRuntimeState('offline');
        }
      }),
    );
  }
}
