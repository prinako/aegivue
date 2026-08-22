import 'package:aegivue/features/cameras/camera_controller.dart';
import 'package:aegivue/features/cameras/presentation/camera_settings_page.dart';
import 'package:aegivue/features/dashboard/presentation/dashboard_page.dart';
import 'package:aegivue/features/dashboard/presentation/dashboard_section_pages.dart';
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
      builder: (context, _) => CameraSettingsPage(
        repository: context.read<CameraController>().repository,
      ),
    ),
    GoRoute(
      path: '/cameras/:id',
      builder: (context, state) {
        final cameras = context.watch<CameraController>();
        final camera = cameras.findById(state.pathParameters['id']!);
        if (camera == null) {
          return const Scaffold(body: Center(child: Text('Camera not found')));
        }
        return CameraSettingsPage(
          repository: cameras.repository,
          camera: camera,
        );
      },
    ),
  ],
);
