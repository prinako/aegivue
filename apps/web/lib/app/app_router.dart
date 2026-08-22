import 'package:aegivue/features/cameras/camera_controller.dart';
import 'package:aegivue/features/cameras/presentation/camera_settings_page.dart';
import 'package:aegivue/features/dashboard/presentation/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const DashboardPage(section: 0)),
    GoRoute(path: '/live', builder: (_, __) => const DashboardPage(section: 1)),
    GoRoute(
      path: '/recordings',
      builder: (_, __) => const DashboardPage(section: 2),
    ),
    GoRoute(
      path: '/events',
      builder: (_, __) => const DashboardPage(section: 3),
    ),
    GoRoute(
      path: '/cameras/new',
      builder: (context, state) => CameraSettingsPage(
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

String pathForSection(int section) => switch (section) {
  1 => '/live',
  2 => '/recordings',
  3 => '/events',
  _ => '/',
};
