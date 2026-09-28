import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/camera_settings_page.dart';
import 'package:aegivue/features/cameras/presentation/view_models/camera_editor_view_model.dart';
import 'package:aegivue/features/cameras/presentation/view_models/camera_list_view_model.dart';
import 'package:aegivue/features/dashboard/presentation/dashboard_page.dart';
import 'package:aegivue/features/dashboard/presentation/events_section_page.dart';
import 'package:aegivue/features/dashboard/presentation/live_section_page.dart';
import 'package:aegivue/features/dashboard/presentation/overview_section_page.dart';
import 'package:aegivue/features/dashboard/presentation/recordings_section_page.dart';
import 'package:aegivue/shared/widgets/app_error_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) =>
          DashboardPage(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const OverviewSectionPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/live', builder: (_, _) => const LiveSectionPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/recordings',
              builder: (_, _) => const RecordingsSectionPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/events',
              builder: (_, _) => const EventsSectionPage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/cameras/new',
      builder: (_, _) => const _CameraEditorRoute(),
    ),
    GoRoute(
      path: '/cameras/:id',
      builder: (_, state) =>
          _CameraEditorRoute(cameraId: state.pathParameters['id']!),
    ),
  ],
);

class _CameraEditorRoute extends StatelessWidget {
  const _CameraEditorRoute({this.cameraId});

  final String? cameraId;

  @override
  Widget build(BuildContext context) {
    final id = cameraId;
    if (id != null) {
      final cameras = context.watch<CameraListViewModel>();
      if (!cameras.loaded) {
        if (cameras.error != null) {
          return Scaffold(body: AppErrorStateWidget(onRetry: cameras.load));
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      final camera = cameras.findById(id);
      if (camera == null) {
        return const Scaffold(body: Center(child: Text('Camera not found')));
      }
      return _provideEditor(context, camera: camera);
    }

    return _provideEditor(context);
  }

  Widget _provideEditor(BuildContext context, {Camera? camera}) {
    return ChangeNotifierProvider(
      create: (context) => CameraEditorViewModel(
        context.read<CameraRepository>(),
        editing: camera != null,
      ),
      child: CameraSettingsPage(camera: camera),
    );
  }
}
