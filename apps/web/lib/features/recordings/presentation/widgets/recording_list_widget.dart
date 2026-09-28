import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_card.dart';
import 'package:flutter/material.dart';

class RecordingListWidget extends StatelessWidget {
  const RecordingListWidget({
    super.key,
    required this.recordings,
    required this.onOpen,
    this.selectedId,
  });

  final List<Recording> recordings;
  final ValueChanged<Recording> onOpen;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    if (recordings.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 4
            : constraints.maxWidth >= 850
            ? 3
            : constraints.maxWidth >= 540
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final recording in recordings)
              SizedBox(
                width: width,
                child: RecordingCard(
                  recording: recording,
                  selected: recording.id == selectedId,
                  onTap: () => onOpen(recording),
                ),
              ),
          ],
        );
      },
    );
  }
}
