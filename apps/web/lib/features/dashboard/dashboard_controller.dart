import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
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

  final CameraRepository cameras;
  final RecordingRepository recordings;

  List<Camera> _cameraItems = const [];
  List<Recording> _recordingItems = const [];
  bool _loading = false;
  Object? _error;
  bool _loaded = false;

  List<Camera> get cameraItems => _cameraItems;
  List<Recording> get recordingItems => _recordingItems;
  bool get loading => _loading;
  Object? get error => _error;
  bool get loaded => _loaded;
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
        recordings.list(),
      ]);
      _cameraItems = List<Camera>.unmodifiable(values[0] as List<Camera>);
      _recordingItems = List<Recording>.unmodifiable(
        values[1] as List<Recording>,
      );
      _loaded = true;
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void upsertCamera(Camera camera) {
    final previous = _cameraItems.where((item) => item.id == camera.id).firstOrNull;
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
