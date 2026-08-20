import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/events/data/event_page.dart';
import 'package:aegivue/features/events/data/event_repository.dart';
import 'package:aegivue/features/events/domain/event.dart';
import 'package:aegivue/features/recordings/data/recording_page.dart';
import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:flutter/foundation.dart';

class DashboardData {
  const DashboardData(this.cameras, this.recordings, this.events);

  final List<Camera> cameras;
  final List<Recording> recordings;
  final List<AegivueEvent> events;
}

class DashboardController extends ChangeNotifier {
  DashboardController(ApiClient api)
    : cameras = CameraRepository(api),
      recordings = RecordingRepository(api),
      events = EventRepository(api);

  static const int _recordingPageSize = 25;
  static const int _eventPageSize = 25;

  final CameraRepository cameras;
  final RecordingRepository recordings;
  final EventRepository events;

  List<Camera> _cameraItems = const [];
  List<Recording> _recordingItems = const [];
  List<AegivueEvent> _eventItems = const [];
  bool _loading = false;
  Object? _error;
  bool _loaded = false;
  int _recordingPage = 1;
  bool _hasMoreRecordings = false;
  bool _loadingMoreRecordings = false;
  int _eventPage = 1;
  bool _hasMoreEvents = false;
  bool _loadingMoreEvents = false;

  List<Camera> get cameraItems => _cameraItems;
  List<Recording> get recordingItems => _recordingItems;
  List<AegivueEvent> get eventItems => _eventItems;
  bool get loading => _loading;
  Object? get error => _error;
  bool get loaded => _loaded;
  bool get hasMoreRecordings => _hasMoreRecordings;
  bool get loadingMoreRecordings => _loadingMoreRecordings;
  bool get hasMoreEvents => _hasMoreEvents;
  bool get loadingMoreEvents => _loadingMoreEvents;
  DashboardData get data => DashboardData(
    _cameraItems,
    _recordingItems,
    _eventItems,
  );

  Future<void> load() => _reload(showLoading: !_loaded);

  Future<void> refresh() => _reload(showLoading: false);

  Future<void> _reload({required bool showLoading}) async {
    if (showLoading) {
      _loading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final values = await Future.wait<Object>([
        cameras.list(),
        recordings.listPage(page: 1, pageSize: _recordingPageSize),
        events.listPage(page: 1, pageSize: _eventPageSize, kind: 'motion'),
      ]);
      _cameraItems = List<Camera>.unmodifiable(values[0] as List<Camera>);

      final recordingPage = values[1] as RecordingPage;
      _recordingItems = List<Recording>.unmodifiable(recordingPage.items);
      _recordingPage = recordingPage.page;
      _hasMoreRecordings = recordingPage.hasMore;

      final eventPage = values[2] as EventPage;
      _eventItems = List<AegivueEvent>.unmodifiable(eventPage.items);
      _eventPage = eventPage.page;
      _hasMoreEvents = eventPage.hasMore;
      _loaded = true;
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreRecordings() async {
    if (_loadingMoreRecordings || !_hasMoreRecordings) return;

    _loadingMoreRecordings = true;
    notifyListeners();

    try {
      final nextPage = await recordings.listPage(
        page: _recordingPage + 1,
        pageSize: _recordingPageSize,
      );
      final existingIds = _recordingItems.map((item) => item.id).toSet();
      final nextItems = [
        ..._recordingItems,
        ...nextPage.items.where((item) => !existingIds.contains(item.id)),
      ];
      _recordingItems = List<Recording>.unmodifiable(nextItems);
      _recordingPage = nextPage.page;
      _hasMoreRecordings = nextPage.hasMore;
    } catch (error) {
      _error = error;
    } finally {
      _loadingMoreRecordings = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreEvents() async {
    if (_loadingMoreEvents || !_hasMoreEvents) return;

    _loadingMoreEvents = true;
    notifyListeners();

    try {
      final nextPage = await events.listPage(
        page: _eventPage + 1,
        pageSize: _eventPageSize,
        kind: 'motion',
      );
      final existingIds = _eventItems.map((item) => item.id).toSet();
      final nextItems = [
        ..._eventItems,
        ...nextPage.items.where((item) => !existingIds.contains(item.id)),
      ];
      _eventItems = List<AegivueEvent>.unmodifiable(nextItems);
      _eventPage = nextPage.page;
      _hasMoreEvents = nextPage.hasMore;
    } catch (error) {
      _error = error;
    } finally {
      _loadingMoreEvents = false;
      notifyListeners();
    }
  }

  Future<void> setRecordingExpiry(
    Recording recording,
    DateTime? expiresAt,
  ) async {
    final updated = await recordings.setExpiry(recording.id, expiresAt);
    final items = [..._recordingItems];
    final index = items.indexWhere((item) => item.id == updated.id);
    if (index != -1) {
      items[index] = updated;
      _recordingItems = List<Recording>.unmodifiable(items);
      notifyListeners();
    }
  }

  void upsertCamera(Camera camera) {
    Camera? previous;
    for (final item in _cameraItems) {
      if (item.id == camera.id) {
        previous = item;
        break;
      }
    }

    final next = camera.withRuntimeState(
      previous?.runtimeState ?? (camera.enabled ? 'offline' : 'disabled'),
    );

    final items = [..._cameraItems];
    final index = items.indexWhere((item) => item.id == camera.id);
    if (index == -1) {
      items.add(next);
    } else {
      items[index] = next;
    }
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _cameraItems = List<Camera>.unmodifiable(items);
    notifyListeners();
  }
}
