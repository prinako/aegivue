@TestOn('browser')
library;

import 'package:aegivue/app/app.dart';
import 'package:aegivue/app/app_router.dart';
import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/view_models/camera_list_view_model.dart';
import 'package:aegivue/features/events/data/event_page.dart';
import 'package:aegivue/features/events/data/event_repository.dart';
import 'package:aegivue/features/events/presentation/view_models/event_list_view_model.dart';
import 'package:aegivue/features/recordings/data/recording_page.dart';
import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/view_models/recording_list_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('header refresh only reloads the active section', (tester) async {
    final cameras = _CameraRepository();
    final recordings = _RecordingRepository();
    final events = _EventRepository();
    appRouter.go('/');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CameraRepository>.value(value: cameras),
          Provider<RecordingRepository>.value(value: recordings),
          Provider<EventRepository>.value(value: events),
          ChangeNotifierProvider(create: (_) => CameraListViewModel(cameras)),
          ChangeNotifierProvider(
            create: (_) => RecordingListViewModel(recordings),
          ),
          ChangeNotifierProvider(create: (_) => EventListViewModel(events)),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recordings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(cameras.listCalls, 0);
    expect(recordings.listCalls, 1);
    expect(events.listCalls, 0);
  });

  testWidgets('overview shows the server recording total', (tester) async {
    final cameras = _CameraRepository();
    final recordings = _RecordingRepository(
      items: [_recording('recording-1')],
      totalItems: 42,
    );
    final events = _EventRepository();
    appRouter.go('/');
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CameraRepository>.value(value: cameras),
          Provider<RecordingRepository>.value(value: recordings),
          Provider<EventRepository>.value(value: events),
          ChangeNotifierProvider(
            create: (_) => CameraListViewModel(cameras)..load(),
          ),
          ChangeNotifierProvider(
            create: (_) => RecordingListViewModel(recordings)..load(),
          ),
          ChangeNotifierProvider(create: (_) => EventListViewModel(events)),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('42'), findsOneWidget);
  });
}

class _CameraRepository extends CameraRepository {
  _CameraRepository() : super(ApiClient());

  int listCalls = 0;

  @override
  Future<List<Camera>> list() async {
    listCalls++;
    return const [];
  }

  @override
  Stream<List<Camera>> runtimeStateUpdates(List<Camera> cameras) =>
      const Stream.empty();
}

class _RecordingRepository extends RecordingRepository {
  _RecordingRepository({this.items = const [], this.totalItems = 0})
    : super(ApiClient());

  int listCalls = 0;
  final List<Recording> items;
  final int totalItems;

  @override
  Future<RecordingPage> listPage({int page = 1, int pageSize = 25}) async {
    listCalls++;
    return RecordingPage(
      items: items,
      page: page,
      pageSize: pageSize,
      totalItems: totalItems,
      totalPages: totalItems == 0 ? 0 : 1,
    );
  }
}

Recording _recording(String id) => Recording(
  id: id,
  cameraId: 'front-door',
  startTime: DateTime.utc(2026, 9, 28),
  container: 'mp4',
  playbackUrl: '/api/v1/recordings/$id/media',
);

class _EventRepository extends EventRepository {
  _EventRepository() : super(ApiClient());

  int listCalls = 0;

  @override
  Future<EventPage> listPage({
    int page = 1,
    int pageSize = 25,
    String? kind,
    String? cameraId,
  }) async {
    listCalls++;
    return EventPage(
      items: const [],
      page: page,
      pageSize: pageSize,
      totalItems: 0,
      totalPages: 0,
    );
  }
}
