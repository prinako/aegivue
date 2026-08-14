import 'package:flutter/material.dart';
import 'core/api_client.dart';
import 'dashboard_controller.dart';
import 'features/cameras/domain/camera.dart';
import 'features/cameras/presentation/camera_settings_page.dart';
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
  late final DashboardController controller;
  late Future<DashboardData> data;

  @override
  void initState() {
    super.initState();
    controller = DashboardController(ApiClient());
    data = controller.load();
  }

  Future<void> refresh() async {
    final fresh = controller.load();
    setState(() => data = fresh);
    await fresh;
  }

  Future<void> _openCameraSettings([Camera? camera]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CameraSettingsPage(
          repository: controller.cameras,
          camera: camera,
        ),
      ),
    );
    if (changed == true) await refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Vigilo'),
      actions: [
        IconButton(
          tooltip: 'Add camera',
          onPressed: () => _openCameraSettings(),
          icon: const Icon(Icons.add_a_photo),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _openCameraSettings(),
      icon: const Icon(Icons.add),
      label: const Text('Add camera'),
    ),
    body: RefreshIndicator(
      onRefresh: refresh,
      child: FutureBuilder<DashboardData>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListView(
              children: const [
                ListTile(title: Text('Unable to load Vigilo data')),
              ],
            );
          }
          if (!snapshot.hasData) {
            return ListView(children: const [LinearProgressIndicator()]);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cameras',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openCameraSettings(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add camera'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (snapshot.data!.cameras.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.videocam_off),
                    title: Text('No cameras configured'),
                    subtitle: Text('Add your first RTSP camera to start recording.'),
                  ),
                )
              else
                ...snapshot.data!.cameras.map(_cameraTile),
              const SizedBox(height: 32),
              Text(
                'Recordings',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              ...snapshot.data!.recordings.map(_recordingTile),
            ],
          );
        },
      ),
    ),
  );

  Widget _cameraTile(Camera camera) {
    final state = camera.runtimeState;
    final online = state == 'online';
    return Card(
      child: ListTile(
        onTap: () => _openCameraSettings(camera),
        leading: Icon(
          online ? Icons.videocam : Icons.videocam_off,
          color: online ? Colors.green : null,
        ),
        title: Text(camera.name),
        subtitle: Text(
          '${camera.id} • ${camera.connection.host}:${camera.connection.port} • '
          '${camera.enabled ? "Enabled" : "Disabled"} • ${_label(state)}',
        ),
        trailing: IconButton(
          tooltip: 'Camera settings',
          onPressed: () => _openCameraSettings(camera),
          icon: const Icon(Icons.settings),
        ),
      ),
    );
  }
}

Widget _recordingTile(Recording recording) => ListTile(
  leading: const Icon(Icons.play_circle),
  title: Text(recording.cameraId),
  subtitle: Text('${recording.startTime.toLocal()} • ${recording.container}'),
);

String _label(String state) => state.isEmpty
    ? 'Unknown'
    : '${state[0].toUpperCase()}${state.substring(1)}';
