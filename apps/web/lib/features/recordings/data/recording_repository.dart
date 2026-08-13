import '../../../core/api_client.dart';
import '../domain/recording.dart';

class RecordingRepository {
  const RecordingRepository(this.api);
  final ApiClient api;
  Future<List<Recording>> list() async {
    final json =
        await api.getJson('/api/v1/recordings') as Map<String, Object?>;
    return (json['items']! as List<Object?>)
        .map((item) => Recording.fromJson(item! as Map<String, Object?>))
        .toList(growable: false);
  }
}
