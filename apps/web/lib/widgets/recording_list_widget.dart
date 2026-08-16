import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:flutter/material.dart';

class RecordingListWidget extends StatelessWidget {
  const RecordingListWidget({super.key, required this.recordings});

  final List<Recording> recordings;

  @override
  Widget build(BuildContext context) {
    if (recordings.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.video_library_outlined, color: Colors.white38),
              SizedBox(width: 12),
              Text(
                'No finalized recordings yet.',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < recordings.length; i++) ...[
            _RecordingRow(recording: recordings[i]),
            if (i != recordings.length - 1)
              const Divider(height: 1, indent: 58),
          ],
        ],
      ),
    );
  }
}

class _RecordingRow extends StatelessWidget {
  const _RecordingRow({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context) {
    final time = recording.startTime.toLocal();
    final stamp =
        '${_two(time.day)}/${_two(time.month)}/${time.year}  ${_two(time.hour)}:${_two(time.minute)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.play_arrow_rounded, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording.cameraId,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  stamp,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            recording.container.toUpperCase(),
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');
