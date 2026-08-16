import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/camera_settings_page.dart';
import 'package:aegivue/features/dashboard/dashboard_controller.dart';
import 'package:aegivue/features/dashboard/presentation/widgets/dashboard_overview.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_library.dart';
import 'package:aegivue/shared/widgets/app_error_state_widget.dart';
import 'package:aegivue/shared/widgets/app_header_widget.dart';
import 'package:aegivue/shared/widgets/side_nav_widget.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController controller;
  late Future<DashboardData> data;
  int section = 0;

  @override
  void initState() {
    super.initState();
    controller = DashboardController(ApiClient());
    data = controller.load();
  }

  Future<void> refresh() async {
    final next = controller.load();
    setState(() => data = next);
    await next;
  }

  Future<void> openCamera([Camera? camera]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CameraSettingsPage(repository: controller.cameras, camera: camera),
      ),
    );
    if (changed == true) await refresh();
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
                    onSelect: (value) => setState(() => section = value),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      AppHeaderWidget(
                        title: section == 0 ? 'Overview' : 'Recordings',
                        onRefresh: refresh,
                        onAdd: () => openCamera(),
                      ),
                      Expanded(
                        child: FutureBuilder<DashboardData>(
                          future: data,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData && !snapshot.hasError) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError || !snapshot.hasData) {
                              return AppErrorStateWidget(onRetry: refresh);
                            }
                            final value = snapshot.data!;
                            return section == 0
                                ? DashboardOverview(
                                    data: value,
                                    onAdd: () => openCamera(),
                                    onEdit: (camera) => openCamera(camera),
                                    onRefresh: refresh,
                                  )
                                : RecordingLibrary(
                                    recordings: value.recordings,
                                    onRefresh: refresh,
                                  );
                          },
                        ),
                      ),
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
                      icon: Icon(Icons.video_library_outlined),
                      label: 'Recordings',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
