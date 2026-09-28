import 'package:aegivue/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class DashboardHero extends StatelessWidget {
  const DashboardHero({super.key, required this.online, required this.total});

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
