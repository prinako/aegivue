import 'package:aegivue/core/utils/formatters.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/live_camera_view.dart';
import 'package:flutter/material.dart';

class FullscreenLiveCameraPage extends StatelessWidget {
  const FullscreenLiveCameraPage({super.key, required this.camera});

  final Camera camera;

  @override
  Widget build(BuildContext context) {
    final online = camera.runtimeState == 'online';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(camera.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                Formatters.cameraState(camera.runtimeState),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: LiveCameraView(cameraId: camera.id, online: online),
        ),
      ),
    );
  }
}
