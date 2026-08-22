import 'package:aegivue/app/app_router.dart';
import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/core/theme/app_theme.dart';
import 'package:aegivue/features/cameras/camera_controller.dart';
import 'package:aegivue/features/events/event_controller.dart';
import 'package:aegivue/features/recordings/recording_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => CameraController(api)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => RecordingController(api)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => EventController(api)..load(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Aegivue',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        routerConfig: appRouter,
      ),
    );
  }
}
