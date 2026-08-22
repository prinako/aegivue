import 'package:aegivue/features/cameras/camera_controller.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/live_view_page.dart';
import 'package:aegivue/features/dashboard/presentation/widgets/dashboard_overview.dart';
import 'package:aegivue/features/events/event_controller.dart';
import 'package:aegivue/features/events/presentation/motion_events_page.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_library.dart';
import 'package:aegivue/features/recordings/recording_controller.dart';
import 'package:aegivue/shared/widgets/app_error_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class OverviewSectionPage extends StatelessWidget {
  const OverviewSectionPage({super.key});

  Future<void> _openCamera(BuildContext context, [Camera? camera]) async {
    final location = camera == null ? '/cameras/new' : '/cameras/${camera.id}';
    final changed = await context.push<bool>(location);
    if (!context.mounted || changed != true) return;
    await context.read<CameraController>().refresh();
  }

  Future<void> _refresh(BuildContext context) async {
    await Future.wait([
      context.read<CameraController>().refresh(),
      context.read<RecordingController>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cameras = context.watch<CameraController>();
    final recordings = context.watch<RecordingController>();
    if ((cameras.loading && !cameras.loaded) ||
        (recordings.loading && !recordings.loaded)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cameras.error != null && !cameras.loaded) {
      return AppErrorStateWidget(onRetry: cameras.load);
    }
    if (recordings.error != null && !recordings.loaded) {
      return AppErrorStateWidget(onRetry: recordings.load);
    }
    return DashboardOverview(
      cameras: cameras.items,
      recordings: recordings.items,
      onAdd: () => _openCamera(context),
      onEdit: (camera) => _openCamera(context, camera),
      onRefresh: () => _refresh(context),
    );
  }
}

class LiveSectionPage extends StatelessWidget {
  const LiveSectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cameras = context.watch<CameraController>();
    if (cameras.loading && !cameras.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cameras.error != null && !cameras.loaded) {
      return AppErrorStateWidget(onRetry: cameras.load);
    }
    return LiveViewPage(cameras: cameras.items, onRefresh: cameras.refresh);
  }
}

class RecordingsSectionPage extends StatelessWidget {
  const RecordingsSectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final recordings = context.watch<RecordingController>();
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
    );
  }
}

class EventsSectionPage extends StatelessWidget {
  const EventsSectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final events = context.watch<EventController>();
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
