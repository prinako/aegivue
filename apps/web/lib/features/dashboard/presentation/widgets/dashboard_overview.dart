import 'package:aegivue/core/theme/app_colors.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/widgets/camera_card.dart';
import 'package:aegivue/features/dashboard/dashboard_controller.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_list_widget.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_player.dart';
import 'package:aegivue/shared/widgets/section_title_widget.dart';
import 'package:flutter/material.dart';

class DashboardOverview extends StatelessWidget {
  const DashboardOverview({
    super.key,
    required this.data,
    required this.onAdd,
    required this.onEdit,
    required this.onRefresh,
  });

  final DashboardData data;
  final VoidCallback onAdd;
  final ValueChanged<Camera> onEdit;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final online = data.cameras
        .where((camera) => camera.runtimeState == 'online')
        .length;
    final recording = data.cameras
        .where((camera) => camera.recording.enabled)
        .length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 44),
        children: [
          _DashboardHero(online: online, total: data.cameras.length),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 850
                  ? 4
                  : constraints.maxWidth >= 500
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 12)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _DashboardMetric(
                    width: width,
                    icon: Icons.videocam_outlined,
                    label: 'Cameras',
                    value: '${data.cameras.length}',
                  ),
                  _DashboardMetric(
                    width: width,
                    icon: Icons.wifi_tethering_rounded,
                    label: 'Online',
                    value: '$online',
                  ),
                  _DashboardMetric(
                    width: width,
                    icon: Icons.fiber_manual_record_rounded,
                    label: 'Recording',
                    value: '$recording',
                  ),
                  _DashboardMetric(
                    width: width,
                    icon: Icons.video_file_outlined,
                    label: 'Clips',
                    value: '${data.recordings.length}',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          SectionTitleWidget(
            title: 'Live cameras',
            subtitle: 'Embedded browser-safe live previews',
            action: onAdd,
          ),
          const SizedBox(height: 12),
          if (data.cameras.isEmpty)
            _EmptyCameras(onAdd: onAdd)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1100
                    ? 3
                    : constraints.maxWidth >= 680
                    ? 2
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.cameras.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: columns == 1 ? 1.75 : 1.35,
                  ),
                  itemBuilder: (context, index) {
                    final camera = data.cameras[index];
                    return CameraCard(
                      camera: camera,
                      onTap: () => onEdit(camera),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 30),
          const SectionTitleWidget(
            title: 'Recent recordings',
            subtitle: 'Latest finalized camera segments',
          ),
          const SizedBox(height: 12),
          RecordingListWidget(
            recordings: data.recordings.take(6).toList(),
            onOpen: (recording) => showDialog<void>(
              context: context,
              builder: (dialogContext) => Dialog(
                insetPadding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 8, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                recording.cameraId,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: RecordingPlayer(
                          playbackUrl: recording.playbackUrl,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.online, required this.total});

  final int online;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF181C2B), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$online of $total cameras online',
                style: const TextStyle(color: Color(0xFF68DDA9), fontSize: 12),
              ),
              const SizedBox(height: 10),
              Text(
                'Your property at a glance',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Monitor live video, camera health, and recent footage from one private console.',
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCameras extends StatelessWidget {
  const _EmptyCameras({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(
              Icons.add_a_photo_outlined,
              size: 40,
              color: Colors.white38,
            ),
            const SizedBox(height: 12),
            const Text(
              'No cameras configured',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 5),
            const Text(
              'Add an RTSP camera to begin monitoring and recording.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 15),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add first camera'),
            ),
          ],
        ),
      ),
    );
  }
}
