import 'package:flutter/material.dart';
import 'core/api_client.dart';
import 'features/cameras/data/camera_repository.dart';
import 'features/cameras/domain/camera.dart';
import 'features/recordings/data/recording_repository.dart';
import 'features/recordings/domain/recording.dart';

void main() => runApp(const VigiloApp());

class VigiloApp extends StatelessWidget {
  const VigiloApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vigilo',
    theme: ThemeData(
      colorSchemeSeed: Colors.indigo,
      brightness: Brightness.dark,
    ),
    home: const Dashboard(),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final api = ApiClient();
  late final cameras = CameraRepository(api).list();
  late final recordings = RecordingRepository(api).list();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vigilo')),
    body: RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Cameras', style: Theme.of(context).textTheme.headlineSmall),
          FutureBuilder<List<Camera>>(
            future: cameras,
            builder: (context, snapshot) => _CameraList(snapshot: snapshot),
          ),
          const SizedBox(height: 32),
          Text('Recordings', style: Theme.of(context).textTheme.headlineSmall),
          FutureBuilder<List<Recording>>(
            future: recordings,
            builder: (context, snapshot) => _RecordingList(snapshot: snapshot),
          ),
        ],
      ),
    ),
  );
}

class _CameraList extends StatelessWidget {
  const _CameraList({required this.snapshot});
  final AsyncSnapshot<List<Camera>> snapshot;
  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return const ListTile(title: Text('Unable to load cameras'));
    }
    if (!snapshot.hasData) return const LinearProgressIndicator();
    return Column(
      children: snapshot.data!
          .map(
            (camera) => ListTile(
              leading: Icon(
                camera.enabled ? Icons.videocam : Icons.videocam_off,
              ),
              title: Text(camera.name),
              subtitle: Text(camera.id),
            ),
          )
          .toList(),
    );
  }
}

class _RecordingList extends StatelessWidget {
  const _RecordingList({required this.snapshot});
  final AsyncSnapshot<List<Recording>> snapshot;
  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return const ListTile(title: Text('Unable to load recordings'));
    }
    if (!snapshot.hasData) return const LinearProgressIndicator();
    return Column(
      children: snapshot.data!
          .map(
            (recording) => ListTile(
              leading: const Icon(Icons.play_circle),
              title: Text(recording.cameraId),
              subtitle: Text(
                '${recording.startTime.toLocal()} • ${recording.container}',
              ),
            ),
          )
          .toList(),
    );
  }
}
