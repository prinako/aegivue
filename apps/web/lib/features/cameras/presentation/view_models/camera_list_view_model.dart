import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:flutter/foundation.dart';

class CameraListViewModel extends ChangeNotifier {
  CameraListViewModel(this._repository);

  final CameraRepository _repository;

  List<Camera> _items = const [];
  bool _loading = false;
  bool _loaded = false;
  Object? _error;
  int _reloadGeneration = 0;
  bool _disposed = false;

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
    final generation = ++_reloadGeneration;
    if (showLoading) {
      _loading = true;
      _notifyListeners();
    }
    _error = null;

    try {
      final cameras = await _repository.list();
      if (_disposed || generation != _reloadGeneration) return;
      _items = List<Camera>.unmodifiable(cameras);
      _loaded = true;
      _loading = false;
      _notifyListeners();

      await for (final cameras in _repository.runtimeStateUpdates(_items)) {
        if (_disposed || generation != _reloadGeneration) return;
        _items = List<Camera>.unmodifiable(cameras);
        _notifyListeners();
      }
    } catch (error) {
      if (_disposed || generation != _reloadGeneration) return;
      _error = error;
    } finally {
      if (generation == _reloadGeneration) {
        _loading = false;
        _notifyListeners();
      }
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
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reloadGeneration++;
    super.dispose();
  }
}
