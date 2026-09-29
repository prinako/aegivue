import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_details_dialog.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_list_widget.dart';
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
            builder: (_) => RecordingDetailsDialog(recording: recording),
          ),
        ),
      ],
    );
  }
}
