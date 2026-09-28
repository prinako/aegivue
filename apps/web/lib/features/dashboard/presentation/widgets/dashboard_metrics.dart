import 'package:flutter/material.dart';

class DashboardMetrics extends StatelessWidget {
  const DashboardMetrics({
    super.key,
    required this.cameras,
    required this.online,
    required this.recording,
    required this.clips,
  });

  final int cameras;
  final int online;
  final int recording;
  final int clips;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 500
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DashboardMetric(
              width: width,
              icon: Icons.videocam_outlined,
              label: 'Cameras',
              value: '$cameras',
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
              value: '$clips',
            ),
          ],
        );
      },
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
