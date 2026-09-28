import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/widgets/camera_card.dart';
import 'package:aegivue/shared/widgets/section_title_widget.dart';
import 'package:flutter/material.dart';

class DashboardCameraGrid extends StatelessWidget {
  const DashboardCameraGrid({
    super.key,
    required this.cameras,
    required this.onAdd,
    required this.onEdit,
  });

  final List<Camera> cameras;
  final VoidCallback onAdd;
  final ValueChanged<Camera> onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitleWidget(
          title: 'Live cameras',
          subtitle: 'Embedded browser-safe live previews',
          action: onAdd,
        ),
        const SizedBox(height: 12),
        if (cameras.isEmpty)
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
                itemCount: cameras.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: columns == 1 ? 1.75 : 1.35,
                ),
                itemBuilder: (context, index) {
                  final camera = cameras[index];
                  return CameraCard(
                    camera: camera,
                    onTap: () => onEdit(camera),
                  );
                },
              );
            },
          ),
      ],
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
