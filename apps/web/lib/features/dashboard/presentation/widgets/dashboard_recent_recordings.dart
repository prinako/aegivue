import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_list_widget.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_player.dart';
import 'package:aegivue/shared/widgets/section_title_widget.dart';
import 'package:flutter/material.dart';

class DashboardRecentRecordings extends StatelessWidget {
  const DashboardRecentRecordings({super.key, required this.recordings});

  final List<Recording> recordings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitleWidget(
          title: 'Recent recordings',
          subtitle: 'Latest finalized camera segments',
        ),
        const SizedBox(height: 12),
        RecordingListWidget(
          recordings: recordings.take(6).toList(),
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
                            onPressed: () => Navigator.of(dialogContext).pop(),
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
    );
  }
}
