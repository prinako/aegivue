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
      return const _EmptyRecordingList();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);
        final cardWidth = _cardWidth(constraints.maxWidth, columns);

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final recording in recordings)
              SizedBox(
                width: cardWidth,
                child: RecordingCard(
                  key: ValueKey(recording.id),
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

class RecordingSliverGrid extends StatelessWidget {
  const RecordingSliverGrid({
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
      return const SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverToBoxAdapter(child: _EmptyRecordingList()),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final columns = _columnCount(width);
          final cardWidth = _cardWidth(width, columns);

          return SliverGrid.builder(
            itemCount: recordings.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: (cardWidth * 9 / 16) + 145,
            ),
            itemBuilder: (context, index) {
              final recording = recordings[index];
              return RecordingCard(
                key: ValueKey(recording.id),
                recording: recording,
                selected: recording.id == selectedId,
                onTap: () => onOpen(recording),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyRecordingList extends StatelessWidget {
  const _EmptyRecordingList();

  @override
  Widget build(BuildContext context) {
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
}

int _columnCount(double width) => width >= 1180
    ? 4
    : width >= 850
    ? 3
    : width >= 540
    ? 2
    : 1;

double _cardWidth(double width, int columns) =>
    (width - ((columns - 1) * 14)) / columns;
