import 'dart:math' as math;

import 'package:aegivue/core/utils/formatters.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/live_camera_view.dart';
import 'package:flutter/material.dart';

class LiveViewPage extends StatelessWidget {
  const LiveViewPage({
    super.key,
    required this.cameras,
    required this.onRefresh,
  });

  final List<Camera> cameras;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (cameras.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.videocam_off_outlined, size: 52, color: Colors.white24),
            SizedBox(height: 14),
            Center(
              child: Text(
                'No cameras registered',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth, cameras.length);
        final spacing = constraints.maxWidth < 700 ? 10.0 : 14.0;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            itemCount: cameras.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: 16 / 10.2,
            ),
            itemBuilder: (context, index) {
              final camera = cameras[index];
              return _LiveCameraTile(
                camera: camera,
                onTap: () => _openFullscreen(context, camera),
              );
            },
          ),
        );
      },
    );
  }

  int _columnCount(double width, int count) {
    final maxByWidth = width >= 1500
        ? 4
        : width >= 1000
        ? 3
        : width >= 620
        ? 2
        : 1;

    final preferredByCount = count <= 1
        ? 1
        : count <= 4
        ? 2
        : count <= 9
        ? 3
        : 4;

    return math.max(1, math.min(maxByWidth, preferredByCount));
  }

  Future<void> _openFullscreen(BuildContext context, Camera camera) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FullscreenLiveCameraPage(camera: camera),
      ),
    );
  }
}

class _LiveCameraTile extends StatelessWidget {
  const _LiveCameraTile({required this.camera, required this.onTap});

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
