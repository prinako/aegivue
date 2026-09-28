import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/domain/camera_configuration.dart';
import 'package:flutter/widgets.dart';

class CameraFormData {
  CameraFormData._(
    CameraConfiguration configuration, {
    required this.editing,
    required String motionFpsText,
  }) : id = TextEditingController(text: configuration.id),
       name = TextEditingController(text: configuration.name),
       host = TextEditingController(text: configuration.host),
       port = TextEditingController(text: '${configuration.port}'),
       username = TextEditingController(text: configuration.username ?? ''),
       password = TextEditingController(),
       mainStream = TextEditingController(text: configuration.mainStream),
       subStream = TextEditingController(text: configuration.subStream ?? ''),
       preEvent = TextEditingController(
         text: '${configuration.preEventSeconds}',
       ),
       postEvent = TextEditingController(
         text: '${configuration.postEventSeconds}',
       ),
       retentionDays = TextEditingController(
         text: configuration.recordingRetentionDays?.toString() ?? '',
       ),
       motionFps = TextEditingController(text: motionFpsText),
       enabled = configuration.enabled,
       recordingEnabled = configuration.recordingEnabled,
       recordingMode = configuration.recordingMode,
       motionEnabled = configuration.motionEnabled,
       motionStream = configuration.motionStream,
       motionSensitivity = configuration.motionSensitivity;

  factory CameraFormData.fromCamera(Camera? camera) {
    final configuration = camera == null
        ? _newCameraDefaults
        : CameraConfiguration.fromCamera(camera);
    return CameraFormData._(
      configuration,
      editing: camera != null,
      motionFpsText: camera == null ? '5' : '${configuration.motionFps}',
    );
  }

  static const _newCameraDefaults = CameraConfiguration(
    id: '',
    name: '',
    enabled: true,
    host: '',
    port: 554,
    mainStream: '',
    recordingEnabled: true,
    recordingMode: 'continuous',
    preEventSeconds: 5,
    postEventSeconds: 15,
    motionEnabled: false,
    motionStream: 'sub',
    motionFps: 5,
    motionSensitivity: 0.65,
  );

  final bool editing;
  final TextEditingController id;
  final TextEditingController name;
  final TextEditingController host;
  final TextEditingController port;
  final TextEditingController username;
  final TextEditingController password;
  final TextEditingController mainStream;
  final TextEditingController subStream;
  final TextEditingController preEvent;
  final TextEditingController postEvent;
  final TextEditingController retentionDays;
  final TextEditingController motionFps;

  bool enabled;
  bool recordingEnabled;
  String recordingMode;
  bool motionEnabled;
  String motionStream;
  double motionSensitivity;

  bool get missingMotionSubStream =>
      motionEnabled && motionStream == 'sub' && subStream.text.trim().isEmpty;

  CameraConfiguration toConfiguration() {
    final usernameValue = username.text.trim();
    final subStreamValue = subStream.text.trim();
    final retentionValue = retentionDays.text.trim();

    return CameraConfiguration(
      id: id.text.trim(),
      name: name.text.trim(),
      enabled: enabled,
      host: host.text.trim(),
      port: int.parse(port.text),
      username: usernameValue.isEmpty ? null : usernameValue,
      password: password.text.isEmpty ? null : password.text,
      mainStream: mainStream.text.trim(),
      subStream: subStreamValue.isEmpty ? null : subStreamValue,
      recordingEnabled: recordingEnabled,
      recordingMode: recordingMode,
      preEventSeconds: int.parse(preEvent.text),
      postEventSeconds: int.parse(postEvent.text),
      recordingRetentionDays: retentionValue.isEmpty
          ? null
          : int.parse(retentionValue),
      motionEnabled: motionEnabled,
      motionStream: motionStream,
      motionFps: double.parse(motionFps.text),
      motionSensitivity: motionSensitivity,
    );
  }

  void dispose() {
    for (final controller in [
      id,
      name,
      host,
      port,
      username,
      password,
      mainStream,
      subStream,
      preEvent,
      postEvent,
      retentionDays,
      motionFps,
    ]) {
      controller.dispose();
    }
  }
}
