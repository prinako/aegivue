import 'package:aegivue/core/api_client.dart';
import 'package:aegivue/dashboard_controller.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/camera_settings_page.dart';
import 'package:aegivue/features/cameras/presentation/live_camera_view.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/utils/app_logo.dart';
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF7482FF);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF11141B),
    );

    return MaterialApp(
      title: 'Aegivue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF090B10),
        dividerColor: Colors.white.withValues(alpha: 0.07),
        cardTheme: CardThemeData(
          color: const Color(0xFF11141B),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D1016),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: scheme.primary, width: 1.4),
          ),
        ),
      ),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
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
                  _SideNav(
                    section: section,
                    onSelect: (value) => setState(() => section = value),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _Header(
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
                              return _ErrorState(onRetry: refresh);
                            }
                            final value = snapshot.data!;
                            return section == 0
                                ? _Overview(
                                    data: value,
                                    onAdd: () => openCamera(),
                                    onEdit: (camera) => openCamera(camera),
                                    onRefresh: refresh,
                                  )
                                : _Recordings(
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

class _SideNav extends StatelessWidget {
  const _SideNav({required this.section, required this.onSelect});

  final int section;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      color: const Color(0xFF0D1016),
      child: Column(
        children: [
           Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 18, 22),
            child: Row(
              children: [
                AppLogo(
                  logoIcon: Image.asset(
                    'aegivue-logo.png',
                  ),
                ),
                SizedBox(width: 11),
                Text(
                  'Aegivue',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          _NavButton(
            icon: Icons.grid_view_rounded,
            label: 'Overview',
            selected: section == 0,
            onTap: () => onSelect(0),
          ),
          _NavButton(
            icon: Icons.video_library_outlined,
            label: 'Recordings',
            selected: section == 1,
            onTap: () => onSelect(1),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 17, color: Colors.white38),
                SizedBox(width: 8),
                Text(
                  'Self-hosted & private',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
      child: Material(
        color: selected ? const Color(0xFF222746) : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : Colors.white54,
                ),
                const SizedBox(width: 11),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white60,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onRefresh,
    required this.onAdd,
  });

  final String title;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Text(
                  'Security monitoring console',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add camera'),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.data,
    required this.onAdd,
    required this.onEdit,
    required this.onRefresh,
  });

  final DashboardData data;
  final VoidCallback onAdd;
  final ValueChanged<Camera> onEdit;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final online = data.cameras
        .where((camera) => camera.runtimeState == 'online')
        .length;
    final recording = data.cameras
        .where((camera) => camera.recording.enabled)
        .length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 44),
        children: [
          _Hero(online: online, total: data.cameras.length, onAdd: onAdd),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 850
                  ? 4
                  : constraints.maxWidth >= 500
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 12)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    width: width,
                    icon: Icons.videocam_outlined,
                    label: 'Cameras',
                    value: '${data.cameras.length}',
                  ),
                  _Metric(
                    width: width,
                    icon: Icons.wifi_tethering_rounded,
                    label: 'Online',
                    value: '$online',
                  ),
                  _Metric(
                    width: width,
                    icon: Icons.fiber_manual_record_rounded,
                    label: 'Recording',
                    value: '$recording',
                  ),
                  _Metric(
                    width: width,
                    icon: Icons.video_file_outlined,
                    label: 'Clips',
                    value: '${data.recordings.length}',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          _SectionTitle(
            title: 'Live cameras',
            subtitle: 'Embedded browser-safe live previews',
            action: onAdd,
          ),
          const SizedBox(height: 12),
          if (data.cameras.isEmpty)
            _EmptyCameras(onAdd: onAdd)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1100
                    ? 3
                    : constraints.maxWidth >= 680
                    ? 2
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.cameras.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: columns == 1 ? 1.75 : 1.35,
                  ),
                  itemBuilder: (context, index) {
                    final camera = data.cameras[index];
                    return _CameraCard(
                      camera: camera,
                      onTap: () => onEdit(camera),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 30),
          const _SectionTitle(
            title: 'Recent recordings',
            subtitle: 'Latest finalized camera segments',
          ),
          const SizedBox(height: 12),
          _RecordingList(recordings: data.recordings.take(6).toList()),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.online, required this.total, required this.onAdd});

  final int online;
  final int total;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF181C2B), Color(0xFF11141B)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$online of $total cameras online',
                style: const TextStyle(color: Color(0xFF68DDA9), fontSize: 12),
              ),
              const SizedBox(height: 10),
              Text(
                'Your property at a glance',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Monitor live video, camera health, and recent footage from one private console.',
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add camera'),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.camera, required this.onTap});

  final Camera camera;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final online = camera.runtimeState == 'online';
    final stateColor = online
        ? const Color(0xFF55D99F)
        : const Color(0xFFFFB65C);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LiveCameraView(cameraId: camera.id, online: online),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
              child: Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: stateColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                camera.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (camera.recording.enabled) ...[
                              const SizedBox(width: 8),
                              const Text(
                                'REC',
                                style: TextStyle(
                                  color: Color(0xFFFF6C78),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_label(camera.runtimeState)} • ${camera.connection.host}:${camera.connection.port}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Camera settings',
                    onPressed: onTap,
                    icon: const Icon(Icons.tune_rounded, size: 19),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        if (action != null)
          TextButton.icon(
            onPressed: action,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add camera'),
          ),
      ],
    );
  }
}

class _EmptyCameras extends StatelessWidget {
  const _EmptyCameras({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(
              Icons.add_a_photo_outlined,
              size: 40,
              color: Colors.white38,
            ),
            const SizedBox(height: 12),
            const Text(
              'No cameras configured',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 5),
            const Text(
              'Add an RTSP camera to begin monitoring and recording.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 15),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add first camera'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Recordings extends StatelessWidget {
  const _Recordings({required this.recordings, required this.onRefresh});

  final List<Recording> recordings;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 44),
        children: [
          Text(
            'Recording library',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Browse finalized footage stored by Vigilo.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          _RecordingList(recordings: recordings),
        ],
      ),
    );
  }
}

class _RecordingList extends StatelessWidget {
  const _RecordingList({required this.recordings});

  final List<Recording> recordings;

  @override
  Widget build(BuildContext context) {
    if (recordings.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.video_library_outlined, color: Colors.white38),
              SizedBox(width: 12),
              Text(
                'No finalized recordings yet.',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (var i = 0; i < recordings.length; i++) ...[
            _RecordingRow(recording: recordings[i]),
            if (i != recordings.length - 1)
              const Divider(height: 1, indent: 58),
          ],
        ],
      ),
    );
  }
}

class _RecordingRow extends StatelessWidget {
  const _RecordingRow({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context) {
    final time = recording.startTime.toLocal();
    final stamp =
        '${_two(time.day)}/${_two(time.month)}/${time.year}  ${_two(time.hour)}:${_two(time.minute)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.play_arrow_rounded, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording.cameraId,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  stamp,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            recording.container.toUpperCase(),
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: Colors.white38),
          const SizedBox(height: 12),
          const Text(
            'Unable to load Vigilo data',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

String _label(String state) => state.isEmpty
    ? 'Unknown'
    : '${state[0].toUpperCase()}${state.substring(1)}';
String _two(int value) => value.toString().padLeft(2, '0');
