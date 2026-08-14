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
  Widget build(BuildContext context) {
    const seed = Color(0xFF6F7DFF);
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF11141B),
    );

    return MaterialApp(
      title: 'Vigilo',
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
            minimumSize: const Size(0, 46),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
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
        final desktop = constraints.maxWidth >= 960;
        return Scaffold(
          drawer: desktop
              ? null
              : _AppDrawer(
                  section: section,
                  onSelect: (value) {
                    Navigator.of(context).pop();
                    setState(() => section = value);
                  },
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  _Sidebar(
                    section: section,
                    onSelect: (value) => setState(() => section = value),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(
                        desktop: desktop,
                        title: section == 0 ? 'Overview' : 'Recordings',
                        onRefresh: refresh,
                        onAdd: () => openCamera(),
                      ),
                      Expanded(
                        child: FutureBuilder<DashboardData>(
                          future: data,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                    ConnectionState.done &&
                                !snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError || !snapshot.hasData) {
                              return _ErrorState(onRetry: refresh);
                            }
                            final value = snapshot.data!;
                            return RefreshIndicator(
                              onRefresh: refresh,
                              child: section == 0
                                  ? _Overview(
                                      data: value,
                                      onAdd: () => openCamera(),
                                      onEdit: (camera) => openCamera(camera),
                                    )
                                  : _Recordings(recordings: value.recordings),
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
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.desktop,
    required this.title,
    required this.onRefresh,
    required this.onAdd,
  });

  final bool desktop;
  final String title;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 30 : 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          if (!desktop) ...[
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const Text(
                  'Security monitoring console',
                  style: TextStyle(color: Colors.white, fontSize: 12),
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
            label: Text(desktop ? 'Add camera' : 'Add'),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.section, required this.onSelect});

  final int section;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 232,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1016),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          const _Brand(),
          const SizedBox(height: 18),
          _NavTile(
            icon: Icons.grid_view_rounded,
            label: 'Overview',
            selected: section == 0,
            onTap: () => onSelect(0),
          ),
          _NavTile(
            icon: Icons.video_library_outlined,
            label: 'Recordings',
            selected: section == 1,
            onTap: () => onSelect(1),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: Colors.white38),
                SizedBox(width: 9),
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

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.section, required this.onSelect});

  final int section;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1016),
      child: SafeArea(
        child: Column(
          children: [
            const _Brand(),
            _NavTile(
              icon: Icons.grid_view_rounded,
              label: 'Overview',
              selected: section == 0,
              onTap: () => onSelect(0),
            ),
            _NavTile(
              icon: Icons.video_library_outlined,
              label: 'Recordings',
              selected: section == 1,
              onTap: () => onSelect(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C88FF), Color(0xFF5260DC)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.visibility_rounded, size: 22),
          ),
          const SizedBox(width: 11),
          Text(
            'Vigilo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
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

class _Overview extends StatelessWidget {
  const _Overview({
    required this.data,
    required this.onAdd,
    required this.onEdit,
  });

  final DashboardData data;
  final VoidCallback onAdd;
  final ValueChanged<Camera> onEdit;

  @override
  Widget build(BuildContext context) {
    final online = data.cameras
        .where((camera) => camera.runtimeState == 'online')
        .length;
    final recording = data.cameras
        .where((camera) => camera.recording.enabled)
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 44),
      children: [
        _Hero(online: online, total: data.cameras.length, onAdd: onAdd),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 880
                ? 4
                : constraints.maxWidth >= 520
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
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
        const SizedBox(height: 32),
        _SectionTitle(
          title: 'Cameras',
          subtitle: 'Live status and recording configuration',
          action: onAdd,
        ),
        const SizedBox(height: 13),
        if (data.cameras.isEmpty)
          _EmptyCameras(onAdd: onAdd)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1120
                  ? 3
                  : constraints.maxWidth >= 700
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
                  childAspectRatio: columns == 1 ? 2.2 : 1.55,
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
        const SizedBox(height: 32),
        const _SectionTitle(
          title: 'Recent recordings',
          subtitle: 'Latest finalized camera segments',
        ),
        const SizedBox(height: 13),
        _RecordingList(recordings: data.recordings.take(6).toList()),
      ],
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
        runSpacing: 18,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 4,
                      backgroundColor: Color(0xFF55D99F),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$online of $total cameras online',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Text(
                  'Your property at a glance',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Monitor camera health, recording status, and recent footage from one private console.',
                  style: TextStyle(color: Colors.white60, height: 1.45),
                ),
              ],
            ),
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
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 13),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF181C25), Color(0xFF0D1016)],
                      ),
                    ),
                    child: Icon(
                      online
                          ? Icons.videocam_outlined
                          : Icons.videocam_off_outlined,
                      size: 46,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  Positioned(
                    left: 11,
                    top: 11,
                    child: _StatusPill(
                      label: _label(camera.runtimeState),
                      color: stateColor,
                    ),
                  ),
                  if (camera.recording.enabled)
                    const Positioned(right: 11, top: 11, child: _RecPill()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          camera.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${camera.connection.host}:${camera.connection.port}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onTap,
                    tooltip: 'Camera settings',
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 3, backgroundColor: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RecPill extends StatelessWidget {
  const _RecPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF351A1F),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fiber_manual_record_rounded,
            color: Color(0xFFFF6C78),
            size: 11,
          ),
          SizedBox(width: 4),
          Text(
            'REC',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Icon(
              Icons.add_a_photo_outlined,
              size: 42,
              color: Colors.white38,
            ),
            const SizedBox(height: 13),
            const Text(
              'No cameras configured',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 5),
            const Text(
              'Add an RTSP camera to begin monitoring and recording.',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
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
  const _Recordings({required this.recordings});

  final List<Recording> recordings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 44),
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
        const SizedBox(height: 22),
        _RecordingList(recordings: recordings),
      ],
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
          padding: EdgeInsets.all(22),
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
    final timestamp =
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
                  timestamp,
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
