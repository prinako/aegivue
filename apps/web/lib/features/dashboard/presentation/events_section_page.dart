import 'package:aegivue/features/events/presentation/motion_events_page.dart';
import 'package:aegivue/features/events/presentation/view_models/event_list_view_model.dart';
import 'package:aegivue/shared/widgets/app_error_state_widget.dart';
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
    return MotionEventsPage(
      events: events.items,
      onRefresh: events.refresh,
      onLoadMore: events.loadMore,
      hasMore: events.hasMore,
      loadingMore: events.loadingMore,
    );
  }
}
