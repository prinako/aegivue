import 'package:aegivue/core/utils/formatters.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/live_camera_view.dart';
import 'package:flutter/material.dart';

class CameraCard extends StatelessWidget {
  const CameraCard({super.key, required this.camera, required this.onTap});

  final Camera camera;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final online = camera.runtimeState == 'online';
    final stateColor = online
        ? const Color(0xFF55D99F)
        : const Color(0xFFFFB65C);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LiveCameraView(cameraId: camera.id, online: online),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
              child: Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: stateColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                camera.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (camera.recording.enabled) ...[
                              const SizedBox(width: 8),
                              const Text(
                                'REC',
                                style: TextStyle(
                                  color: Color(0xFFFF6C78),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${Formatters.cameraState(camera.runtimeState)} • '
                          '${camera.connection.host}:${camera.connection.port}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Camera settings',
                    onPressed: onTap,
                    icon: const Icon(Icons.tune_rounded, size: 19),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
