import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/camera_settings_page.dart';
import 'package:aegivue/features/cameras/presentation/live_view_page.dart';
import 'package:aegivue/features/dashboard/dashboard_controller.dart';
import 'package:aegivue/features/dashboard/presentation/widgets/dashboard_overview.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_library.dart';
import 'package:aegivue/shared/widgets/app_error_state_widget.dart';
import 'package:aegivue/shared/widgets/app_header_widget.dart';
import 'package:aegivue/shared/widgets/side_nav_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int section = 0;

  Future<void> openCamera([Camera? camera]) async {
    final controller = context.read<DashboardController>();
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CameraSettingsPage(repository: controller.cameras, camera: camera),
      ),
    );
    if (!mounted || changed != true) return;
    await controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();

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
                    onSelect: (value) => setState(() => section = value),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      AppHeaderWidget(
                        title: _titleForSection(section),
                        onRefresh: controller.refresh,
                        onAdd: () => openCamera(),
                      ),
                      Expanded(child: _buildContent(controller)),
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
                      setState(() => section = value),
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
                  ],
                ),
        );
      },
    );
  }

  String _titleForSection(int value) => switch (value) {
    1 => 'Live view',
    2 => 'Recordings',
    _ => 'Overview',
  };

  Widget _buildContent(DashboardController controller) {
    if (controller.loading && !controller.loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null && !controller.loaded) {
      return AppErrorStateWidget(onRetry: controller.load);
    }

    final data = controller.data;
    return switch (section) {
      1 => LiveViewPage(cameras: data.cameras, onRefresh: controller.refresh),
      2 => RecordingLibrary(
        recordings: data.recordings,
        onRefresh: controller.refresh,
      ),
      _ => DashboardOverview(
        data: data,
        onAdd: () => openCamera(),
        onEdit: (camera) => openCamera(camera),
        onRefresh: controller.refresh,
      ),
    };
  }
}
