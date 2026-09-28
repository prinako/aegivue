import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/domain/camera_configuration.dart';
import 'package:flutter/foundation.dart';

class CameraEditorViewModel extends ChangeNotifier {
  CameraEditorViewModel(this._repository, {this.editing = false});

  final CameraRepository _repository;
  final bool editing;

  bool _saving = false;
  Object? _error;
  Camera? _savedCamera;

  bool get saving => _saving;
  Object? get error => _error;
  Camera? get savedCamera => _savedCamera;

  Future<bool> save(CameraConfiguration configuration) async {
    _saving = true;
    _error = null;
    _savedCamera = null;
    notifyListeners();

    try {
      _savedCamera = editing
          ? await _repository.update(configuration)
          : await _repository.create(configuration);
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
