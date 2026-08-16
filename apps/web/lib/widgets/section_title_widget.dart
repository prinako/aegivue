import 'package:flutter/material.dart';

class SectionTitleWidget extends StatelessWidget {
  const SectionTitleWidget({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        if (action != null)
          TextButton.icon(
            onPressed: action,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add camera'),
          ),
      ],
    );
  }
}
