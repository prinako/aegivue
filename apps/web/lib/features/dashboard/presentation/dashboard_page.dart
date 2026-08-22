import 'package:aegivue/features/cameras/camera_controller.dart';
import 'package:aegivue/features/events/event_controller.dart';
import 'package:aegivue/features/recordings/recording_controller.dart';
import 'package:aegivue/shared/widgets/app_header_widget.dart';
import 'package:aegivue/shared/widgets/side_nav_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  Future<void> _addCamera(BuildContext context) async {
    final changed = await context.push<bool>('/cameras/new');
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
    final section = navigationShell.currentIndex;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 920;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  SideNavWidget(section: section, onSelect: _openSection),
                Expanded(
                  child: Column(
                    children: [
                      AppHeaderWidget(
                        title: _titleForSection(section),
                        onRefresh: () => _refreshAll(context),
                        onAdd: section <= 1 ? () => _addCamera(context) : null,
                      ),
                      Expanded(child: navigationShell),
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
                  onDestinationSelected: _openSection,
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

  String _titleForSection(int section) => switch (section) {
    1 => 'Live view',
    2 => 'Recordings',
    3 => 'Motion events',
    _ => 'Overview',
  };

  void _openSection(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
