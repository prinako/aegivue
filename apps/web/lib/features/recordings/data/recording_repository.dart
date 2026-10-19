import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/core/api/api_endpoints.dart';
import 'package:aegivue/features/recordings/data/recording_page.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/domain/recording_timeline_interval.dart';

class RecordingRepository {
  const RecordingRepository(this.api);
  final ApiClient api;

  Future<List<Recording>> list() async => (await listPage()).items;

  Future<RecordingPage> listPage({
    int page = 1,
    int pageSize = 25,
    DateTime? from,
    DateTime? to,
    Set<String> cameraIds = const {},
  }) async {
    final sortedCameraIds = cameraIds.toList()..sort();
    final queryParameters = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
      if (sortedCameraIds.isNotEmpty) 'cameraIds': sortedCameraIds.join(','),
    };
    final uri = Uri(
      path: ApiEndpoints.recordings,
      queryParameters: queryParameters,
    );
    final json = await api.getJson(uri.toString()) as Map<String, Object?>;

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

  Future<Recording> setExpiry(String id, DateTime? expiresAt) async {
    final json =
        await api.patchJson(
              '${ApiEndpoints.recordings}/$id/expiry',
              data: {'expiresAt': expiresAt?.toUtc().toIso8601String()},
            )
            as Map<String, Object?>;
    return Recording.fromJson(json);
  }

  Future<List<RecordingTimelineInterval>> timeline({
    required DateTime from,
    required DateTime to,
    Set<String> cameraIds = const {},
  }) async {
    final sortedCameraIds = cameraIds.toList()..sort();
    final uri = Uri(
      path: ApiEndpoints.recordingTimeline,
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        if (sortedCameraIds.isNotEmpty) 'cameraIds': sortedCameraIds.join(','),
      },
    );
    final json = await api.getJson(uri.toString()) as Map<String, Object?>;
    return (json['items']! as List<Object?>)
        .map(
          (item) =>
              RecordingTimelineInterval.fromJson(item! as Map<String, Object?>),
        )
        .toList(growable: false);
  }

  Future<Recording> find(String id) async {
    final json =
        await api.getJson('${ApiEndpoints.recordings}/$id')
            as Map<String, Object?>;
    return Recording.fromJson(json);
  }
}
