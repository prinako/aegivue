import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/core/api/api_endpoints.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';

class RecordingRepository {
  const RecordingRepository(this.api);
  final ApiClient api;
  Future<List<Recording>> list() async {
    final json =
        await api.getJson(ApiEndpoints.recordings) as Map<String, Object?>;
    return (json['items']! as List<Object?>)
        .map((item) => Recording.fromJson(item! as Map<String, Object?>))
        .toList(growable: false);
  }
}
