import 'package:aegivue/features/events/presentation/motion_events_page.dart';
import 'package:aegivue/features/events/presentation/view_models/event_list_view_model.dart';
import 'package:aegivue/shared/widgets/app_error_state_widget.dart';
import 'package:aegivue/shared/widgets/app_inline_error_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EventsSectionPage extends StatelessWidget {
  const EventsSectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventListViewModel>();
    if (events.loading && !events.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (events.error != null && !events.loaded) {
      return AppErrorStateWidget(onRetry: events.load);
    }
    return Column(
      children: [
        if (events.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: AppInlineErrorWidget(
              message: 'Unable to refresh motion events',
              onRetry: events.refresh,
            ),
          ),
        Expanded(
          child: MotionEventsPage(
            events: events.items,
            onRefresh: events.refresh,
            onLoadMore: events.loadMore,
            hasMore: events.hasMore,
            loadingMore: events.loadingMore,
          ),
        ),
      ],
    );
  }
}
