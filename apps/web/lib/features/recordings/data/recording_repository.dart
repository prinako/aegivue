import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/core/api/api_endpoints.dart';
import 'package:aegivue/features/recordings/data/recording_page.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';

class RecordingRepository {
  const RecordingRepository(this.api);
  final ApiClient api;

  Future<List<Recording>> list() async => (await listPage()).items;

  Future<RecordingPage> listPage({int page = 1, int pageSize = 25}) async {
    final json =
        await api.getJson(
              '${ApiEndpoints.recordings}?page=$page&pageSize=$pageSize',
            )
            as Map<String, Object?>;

    return RecordingPage(
      items: (json['items']! as List<Object?>)
          .map((item) => Recording.fromJson(item! as Map<String, Object?>))
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? page,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? pageSize,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}
