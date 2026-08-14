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
    const seed = Color(0xFF6D7CFF);
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
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0D1016),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.primary, width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.04),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFF0D1016),
          indicatorColor: Color(0xFF252B4C),
          useIndicator: true,
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
  int selectedSection = 0;

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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 960;
        return Scaffold(
          drawer: desktop ? null : _MobileDrawer(onSelect: _selectSection),
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  _DesktopNavigation(
                    selectedIndex: selectedSection,
                    onSelect: _selectSection,
                  ),
                Expanded(
                  child: FutureBuilder<DashboardData>(
                    future: data,
                    builder: (context, snapshot) {
                      return _DashboardBody(
                        desktop: desktop,
                        selectedSection: selectedSection,
                        snapshot: snapshot,
                        onRefresh: refresh,
                        onAddCamera: () => _openCameraSettings(),
                        onEditCamera: _openCameraSettings,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectSection(int value) {
    setState(() => selectedSection = value);
    if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.desktop,
    required this.selectedSection,
    required this.snapshot,
    required this.onRefresh,
    required this.onAddCamera,
    required this.onEditCamera,
  });

  final bool desktop;
  final int selectedSection;
  final AsyncSnapshot<DashboardData> snapshot;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddCamera;
  final Future<void> Function(Camera camera) onEditCamera;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(
          desktop: desktop,
          title: selectedSection == 0 ? 'Overview' : 'Recordings',
          onRefresh: onRefresh,
          onAddCamera: onAddCamera,
        ),
        Expanded(
          child: _buildContent(context),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError || !snapshot.hasData) {
      return _ErrorState(onRetry: onRefresh);
    }

    final dashboard = snapshot.data!;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: selectedSection == 0
          ? _OverviewPage(
              data: dashboard,
              onAddCamera: onAddCamera,
              onEditCamera: onEditCamera,
            )
          : _RecordingsPage(recordings: dashboard.recordings),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.desktop,
    required this.title,
    required this.onRefresh,
    required this.onAddCamera,
  });

  final bool desktop;
  final String title;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: EdgeInsets.symmetric(horizontal: desktop ? 32 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF090B10),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
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
            const SizedBox(width: 12),
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
                const SizedBox(height: 2),
                Text(
                  'Security monitoring console',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onAddCamera,
            icon: const Icon(Icons.add_rounded),
            label: Text(desktop ? 'Add camera' : 'Add'),
          ),
        ],
      ),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1016),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Column(
        children: [
          const _Brand(),
          const SizedBox(height: 18),
          _NavItem(
            icon: Icons.grid_view_rounded,
            label: 'Overview',
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            icon: Icons.video_library_outlined,
            label: 'Recordings',
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 19),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Self-hosted\n& private',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  const _MobileDrawer({required this.onSelect});

  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1016),
      child: SafeArea(
        child: Column(
          children: [
            const _Brand(),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text('Overview'),
              onTap: () => onSelect(0),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Recordings'),
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
      padding: const EdgeInsets.fromLTRB(22, 24, 18, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7B87FF), Color(0xFF4F5BD5)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.visibility_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: selected ? const Color(0xFF222746) : Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? Colors.white : Colors.white54),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : Colors.white60,
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

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({
    required this.data,
    required this.onAddCamera,
    required this.onEditCamera,
  });

  final DashboardData data;
  final VoidCallback onAddCamera;
  final Future<void> Function(Camera camera) onEditCamera;

  @override
  Widget build(BuildContext context) {
    final online = data.cameras.where((camera) => camera.runtimeState == 'online').length;
    final recording = data.cameras.where((camera) => camera.recording.enabled).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
      children: [
        _HeroHeader(
          cameraCount: data.cameras.length,
          onlineCount: online,
          onAddCamera: onAddCamera,
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 560 ? 2 : 1;
            final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(width: width, label: 'Cameras', value: '${data.cameras.length}', icon: Icons.videocam_outlined),
                _MetricCard(width: width, label: 'Online', value: '$online', icon: Icons.wifi_tethering_rounded, positive: online > 0),
                _MetricCard(width: width, label: 'Recording', value: '$recording', icon: Icons.fiber_manual_record_rounded),
                _MetricCard(width: width, label: 'Clips', value: '${data.recordings.length}', icon: Icons.video_file_outlined),
              ],
            );
          },
        ),
        const SizedBox(height: 34),
        _SectionHeader(
          title: 'Cameras',
          subtitle: 'Live status and recording configuration',
          action: TextButton.icon(
            onPressed: onAddCamera,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add camera'),
          ),
        ),
        const SizedBox(height: 14),
        if (data.cameras.isEmpty)
          _EmptyCameras(onAddCamera: onAddCamera)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1180 ? 3 : constraints.maxWidth >= 720 ? 2 : 1;
              final ratio = columns == 1 ? 2.35 : 1.55;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.cameras.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: ratio,
                ),
                itemBuilder: (context, index) {
                  final camera = data.cameras[index];
                  return _CameraCard(camera: camera, onTap: () => onEditCamera(camera));
                },
              );
            },
          ),
        const SizedBox(height: 34),
        _SectionHeader(
          title: 'Recent recordings',
          subtitle: 'Latest finalized camera segments',
          action: null,
        ),
        const SizedBox(height: 14),
        _RecentRecordings(recordings: data.recordings.take(6).toList()),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.cameraCount, required this.onlineCount, required this.onAddCamera});

  final int cameraCount;
  final int onlineCount;
  final VoidCallback onAddCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF181C2B), Color(0xFF11141B)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 18,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF4ED49A), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$onlineCount of $cameraCount cameras online',
                      style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Your property at a glance',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor camera health, recording status, and recent footage from one private console.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60, height: 1.45),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onAddCamera,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add camera'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    this.positive = false,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: positive
                      ? const Color(0xFF173629)
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 21, color: positive ? const Color(0xFF5DE1A6) : null),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
    final disabled = !camera.enabled;
    final stateColor = online ? const Color(0xFF55D99F) : disabled ? Colors.white38 : const Color(0xFFFFB65C);

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
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF181C25), Color(0xFF0D1016)],
                      ),
                    ),
                    child: Icon(
                      online ? Icons.videocam_outlined : Icons.videocam_off_outlined,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _StatusPill(label: _label(camera.runtimeState), color: stateColor),
                  ),
                  if (camera.recording.enabled)
                    const Positioned(
                      top: 12,
                      right: 12,
                      child: _RecordingPill(),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
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
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${camera.connection.host}:${camera.connection.port}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white46, fontSize: 12),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RecordingPill extends StatelessWidget {
  const _RecordingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF32191D).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fiber_manual_record_rounded, color: Color(0xFFFF6C78), size: 12),
          SizedBox(width: 5),
          Text('REC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, required this.action});

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w750)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Colors.white46, fontSize: 12)),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _RecentRecordings extends StatelessWidget {
  const _RecentRecordings({required this.recordings});

  final List<Recording> recordings;

  @override
  Widget build(BuildContext context) {
    if (recordings.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(Icons.video_library_outlined, color: Colors.white38),
              SizedBox(width: 14),
              Expanded(child: Text('No finalized recordings yet.', style: TextStyle(color: Colors.white54))),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (var index = 0; index < recordings.length; index++) ...[
            _RecordingRow(recording: recordings[index]),
            if (index != recordings.length - 1) const Divider(height: 1, indent: 62),
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
    final timestamp = '${_two(time.day)}/${_two(time.month)}/${time.year}  ${_two(time.hour)}:${_two(time.minute)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.play_arrow_rounded, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recording.cameraId, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(timestamp, style: const TextStyle(color: Colors.white46, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(recording.container.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}

class _RecordingsPage extends StatelessWidget {
  const _RecordingsPage({required this.recordings});

  final List<Recording> recordings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
      children: [
        Text(
          'Recording library',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.7),
        ),
        const SizedBox(height: 6),
        const Text('Browse finalized footage stored by Vigilo.', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 24),
        _RecentRecordings(recordings: recordings),
      ],
    );
  }
}

class _EmptyCameras extends StatelessWidget {
  const _EmptyCameras({required this.onAddCamera});

  final VoidCallback onAddCamera;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_outlined),
            ),
            const SizedBox(height: 16),
            const Text('No cameras configured', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            const Text('Add an RTSP camera to begin monitoring and recording.', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: onAddCamera, icon: const Icon(Icons.add_rounded), label: const Text('Add first camera')),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42, color: Colors.white38),
            const SizedBox(height: 14),
            const Text('Unable to load Vigilo data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 7),
            const Text('Check the API connection and try again.', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 18),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

String _label(String state) => state.isEmpty
    ? 'Unknown'
    : '${state[0].toUpperCase()}${state.substring(1)}';

String _two(int value) => value.toString().padLeft(2, '0');
