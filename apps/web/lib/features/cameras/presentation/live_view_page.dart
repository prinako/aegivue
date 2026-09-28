import 'dart:math' as math;

import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/fullscreen_live_camera_page.dart';
import 'package:aegivue/features/cameras/presentation/widgets/live_camera_tile.dart';
import 'package:flutter/material.dart';

class LiveViewPage extends StatelessWidget {
  static const id = 'live-view';
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
              return LiveCameraTile(
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
