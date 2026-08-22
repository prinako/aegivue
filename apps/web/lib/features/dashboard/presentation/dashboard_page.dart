import 'package:aegivue/app/app_router.dart';
import 'package:aegivue/features/cameras/camera_controller.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/live_view_page.dart';
import 'package:aegivue/features/dashboard/presentation/widgets/dashboard_overview.dart';
import 'package:aegivue/features/events/event_controller.dart';
import 'package:aegivue/features/events/presentation/motion_events_page.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_library.dart';
import 'package:aegivue/features/recordings/recording_controller.dart';
import 'package:aegivue/shared/widgets/app_error_state_widget.dart';
import 'package:aegivue/shared/widgets/app_header_widget.dart';
import 'package:aegivue/shared/widgets/side_nav_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.section});

  final int section;

  Future<void> _openCamera(BuildContext context, [Camera? camera]) async {
    final path = camera == null ? '/cameras/new' : '/cameras/${camera.id}';
    final changed = await context.push<bool>(path);
    if (!context.mounted || changed != true) return;
    await context.read<CameraController>().refresh();
  }

  Future<void> _refreshAll(BuildContext context) async {
    await Future.wait([
      context.read<CameraController>().refresh(),
      context.read<RecordingController>().refresh(),
      context.read<EventController>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 920;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  SideNavWidget(
                    section: section,
                    onSelect: (value) => context.go(pathForSection(value)),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      AppHeaderWidget(
                        title: _titleForSection(section),
                        onRefresh: () => _refreshAll(context),
                        onAdd: section <= 1 ? () => _openCamera(context) : null,
                      ),
                      Expanded(child: _buildContent(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: section,
                  onDestinationSelected: (value) =>
                      context.go(pathForSection(value)),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_rounded),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.live_tv_rounded),
                      label: 'Live',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.video_library_outlined),
                      label: 'Recordings',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.motion_photos_on_outlined),
                      label: 'Motion',
                    ),
                  ],
                ),
        );
      },
    );
  }

  String _titleForSection(int value) => switch (value) {
    1 => 'Live view',
    2 => 'Recordings',
    3 => 'Motion events',
    _ => 'Overview',
  };

  Widget _buildContent(BuildContext context) {
    switch (section) {
      case 1:
        final cameras = context.watch<CameraController>();
        if (cameras.loading && !cameras.loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        if (cameras.error != null && !cameras.loaded) {
          return AppErrorStateWidget(onRetry: cameras.load);
        }
        return LiveViewPage(cameras: cameras.items, onRefresh: cameras.refresh);
      case 2:
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
      case 3:
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
      default:
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
          onRefresh: () => _refreshAll(context),
        );
    }
  }
}
