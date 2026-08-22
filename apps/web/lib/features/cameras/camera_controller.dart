import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:flutter/foundation.dart';

class CameraController extends ChangeNotifier {
  CameraController(ApiClient api) : repository = CameraRepository(api);

  final CameraRepository repository;

  List<Camera> _items = const [];
  bool _loading = false;
  bool _loaded = false;
  Object? _error;

  List<Camera> get items => _items;
  bool get loading => _loading;
  bool get loaded => _loaded;
  Object? get error => _error;

  Camera? findById(String id) {
    for (final camera in _items) {
      if (camera.id == id) return camera;
    }
    return null;
  }

  Future<void> load() => _reload(showLoading: !_loaded);

  Future<void> refresh() => _reload(showLoading: false);

  Future<void> _reload({required bool showLoading}) async {
    if (showLoading) {
      _loading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final cameras = await repository.list();
      _items = List<Camera>.unmodifiable(cameras);
      _loaded = true;
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void upsert(Camera camera) {
    Camera? previous;
    for (final item in _items) {
      if (item.id == camera.id) {
        previous = item;
        break;
      }
    }

    final next = camera.withRuntimeState(
      previous?.runtimeState ?? (camera.enabled ? 'offline' : 'disabled'),
    );
    final items = [..._items];
    final index = items.indexWhere((item) => item.id == camera.id);
    if (index == -1) {
      items.add(next);
    } else {
      items[index] = next;
    }
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _items = List<Camera>.unmodifiable(items);
    notifyListeners();
  }
}
