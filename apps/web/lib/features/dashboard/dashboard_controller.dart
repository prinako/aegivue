import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/recordings/data/recording_page.dart';
import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:flutter/foundation.dart';

class DashboardData {
  const DashboardData(this.cameras, this.recordings);

  final List<Camera> cameras;
  final List<Recording> recordings;
}

class DashboardController extends ChangeNotifier {
  DashboardController(ApiClient api)
    : cameras = CameraRepository(api),
      recordings = RecordingRepository(api);

  static const int _recordingPageSize = 25;

  final CameraRepository cameras;
  final RecordingRepository recordings;

  List<Camera> _cameraItems = const [];
  List<Recording> _recordingItems = const [];
  bool _loading = false;
  Object? _error;
  bool _loaded = false;
  int _recordingPage = 1;
  bool _hasMoreRecordings = false;
  bool _loadingMoreRecordings = false;

  List<Camera> get cameraItems => _cameraItems;
  List<Recording> get recordingItems => _recordingItems;
  bool get loading => _loading;
  Object? get error => _error;
  bool get loaded => _loaded;
  bool get hasMoreRecordings => _hasMoreRecordings;
  bool get loadingMoreRecordings => _loadingMoreRecordings;
  DashboardData get data => DashboardData(_cameraItems, _recordingItems);

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
      ]);
      _cameraItems = List<Camera>.unmodifiable(values[0] as List<Camera>);
      final page = values[1] as RecordingPage;
      _recordingItems = List<Recording>.unmodifiable(page.items);
      _recordingPage = page.page;
      _hasMoreRecordings = page.hasMore;
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
