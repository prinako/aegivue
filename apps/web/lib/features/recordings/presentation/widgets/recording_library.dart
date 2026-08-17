import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_list_widget.dart';
import 'package:flutter/material.dart';

class RecordingLibrary extends StatelessWidget {
  const RecordingLibrary({
    super.key,
    required this.recordings,
    required this.onRefresh,
  });

  final List<Recording> recordings;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 44),
        children: [
          Text(
            'Recording library',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Browse finalized footage stored by Vigilo.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          RecordingListWidget(recordings: recordings),
        ],
      ),
    );
  }
}
