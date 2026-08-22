import 'package:aegivue/app/app.dart';
import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/cameras/camera_controller.dart';
import 'package:aegivue/features/events/event_controller.dart';
import 'package:aegivue/features/recordings/recording_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

void main() {
  usePathUrlStrategy();
  final api = ApiClient();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CameraController(api)..load()),
        ChangeNotifierProvider(create: (_) => RecordingController(api)..load()),
        ChangeNotifierProvider(create: (_) => EventController(api)..load()),
      ],
      child: const App(),
    ),
  );
}
