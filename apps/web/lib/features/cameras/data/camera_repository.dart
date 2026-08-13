import '../../../core/api_client.dart';
import '../domain/camera.dart';

class CameraRepository {
  const CameraRepository(this.api);
  final ApiClient api;
  Future<List<Camera>> list() async {
    final json = await api.getJson('/api/v1/cameras') as List<Object?>;
    return json
        .map((item) => Camera.fromJson(item! as Map<String, Object?>))
        .toList(growable: false);
  }
}
