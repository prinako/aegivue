import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/dashboard/presentation/widgets/dashboard_camera_grid.dart';
import 'package:aegivue/features/dashboard/presentation/widgets/dashboard_hero.dart';
import 'package:aegivue/features/dashboard/presentation/widgets/dashboard_metrics.dart';
import 'package:aegivue/features/dashboard/presentation/widgets/dashboard_recent_recordings.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:flutter/material.dart';

class DashboardOverview extends StatelessWidget {
  const DashboardOverview({
    super.key,
    required this.cameras,
    required this.recordings,
    required this.onAdd,
    required this.onEdit,
    required this.onRefresh,
  });

  final List<Camera> cameras;
  final List<Recording> recordings;
  final VoidCallback onAdd;
  final ValueChanged<Camera> onEdit;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final online = cameras
        .where((camera) => camera.runtimeState == 'online')
        .length;
    final recording = cameras
        .where((camera) => camera.recording.enabled)
        .length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 44),
        children: [
          DashboardHero(online: online, total: cameras.length),
          const SizedBox(height: 18),
          DashboardMetrics(
            cameras: cameras.length,
            online: online,
            recording: recording,
            clips: recordings.length,
          ),
          const SizedBox(height: 30),
          DashboardCameraGrid(cameras: cameras, onAdd: onAdd, onEdit: onEdit),
          const SizedBox(height: 30),
          DashboardRecentRecordings(recordings: recordings),
        ],
      ),
    );
  }
}
