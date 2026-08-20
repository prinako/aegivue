import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/core/api/api_endpoints.dart';
import 'package:aegivue/features/events/data/event_page.dart';
import 'package:aegivue/features/events/domain/event.dart';

class EventRepository {
  const EventRepository(this.api);

  final ApiClient api;

  Future<EventPage> listPage({
    int page = 1,
    int pageSize = 25,
    String? kind,
    String? cameraId,
  }) async {
    final query = <String>[
      'page=$page',
      'pageSize=$pageSize',
      if (kind != null && kind.isNotEmpty) 'kind=$kind',
      if (cameraId != null && cameraId.isNotEmpty) 'cameraId=$cameraId',
    ].join('&');

    final json =
        await api.getJson('${ApiEndpoints.events}?$query')
            as Map<String, Object?>;

    return EventPage(
      items: (json['items']! as List<Object?>)
          .map((item) => AegivueEvent.fromJson(item! as Map<String, Object?>))
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? page,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? pageSize,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}
