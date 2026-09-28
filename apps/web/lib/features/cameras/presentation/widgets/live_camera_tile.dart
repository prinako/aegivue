import 'package:aegivue/core/utils/formatters.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/live_camera_view.dart';
import 'package:flutter/material.dart';

class LiveCameraTile extends StatelessWidget {
  const LiveCameraTile({super.key, required this.camera, required this.onTap});

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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LiveCameraView(cameraId: camera.id, online: online),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.fullscreen_rounded, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: stateColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          camera.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.cameraState(camera.runtimeState),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (camera.recording.enabled)
                    const Text(
                      'REC',
                      style: TextStyle(
                        color: Color(0xFFFF6C78),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
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
