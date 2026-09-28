import 'package:aegivue/app/app.dart';
import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:aegivue/features/cameras/presentation/view_models/camera_list_view_model.dart';
import 'package:aegivue/features/events/data/event_repository.dart';
import 'package:aegivue/features/events/presentation/view_models/event_list_view_model.dart';
import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:aegivue/features/recordings/presentation/view_models/recording_list_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

void main() {
  usePathUrlStrategy();
  final api = ApiClient();
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => CameraRepository(api)),
        Provider(create: (_) => RecordingRepository(api)),
        Provider(create: (_) => EventRepository(api)),
        ChangeNotifierProvider(
          create: (context) =>
              CameraListViewModel(context.read<CameraRepository>())..load(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              RecordingListViewModel(context.read<RecordingRepository>())
                ..load(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              EventListViewModel(context.read<EventRepository>())..load(),
        ),
      ],
      child: const App(),
    ),
  );
}
