import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:flutter/material.dart';

class RecordingExpirySheet extends StatelessWidget {
  const RecordingExpirySheet({
    super.key,
    required this.recording,
    required this.onPick,
    required this.onClear,
  });

  final Recording recording;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Recording expiry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              recording.expiresAt == null
                  ? 'This recording is currently kept indefinitely.'
                  : 'Current expiry: ${_formatExpiry(recording.expiresAt!)}',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.event_rounded),
              label: const Text('Choose expiry date'),
            ),
            if (recording.expiresAt != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.all_inclusive_rounded),
                label: const Text('Keep indefinitely'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatExpiry(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
