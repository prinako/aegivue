import 'package:aegivue/features/recordings/presentation/view_models/recording_list_view_model.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_library.dart';
import 'package:aegivue/shared/widgets/app_error_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecordingsSectionPage extends StatelessWidget {
  const RecordingsSectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final recordings = context.watch<RecordingListViewModel>();
    if (recordings.loading && !recordings.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (recordings.error != null && !recordings.loaded) {
      return AppErrorStateWidget(onRetry: recordings.load);
    }
    return RecordingLibrary(
      recordings: recordings.items,
      onRefresh: recordings.refresh,
      onLoadMore: recordings.loadMore,
      onSetExpiry: recordings.setExpiry,
      hasMore: recordings.hasMore,
      loadingMore: recordings.loadingMore,
      updatingExpiry: recordings.updatingExpiry,
    );
  }
}
