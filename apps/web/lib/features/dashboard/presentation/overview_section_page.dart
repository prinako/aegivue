import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/view_models/camera_list_view_model.dart';
import 'package:aegivue/features/dashboard/presentation/widgets/dashboard_overview.dart';
import 'package:aegivue/features/recordings/presentation/view_models/recording_list_view_model.dart';
import 'package:aegivue/shared/widgets/app_error_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class OverviewSectionPage extends StatelessWidget {
  const OverviewSectionPage({super.key});

  Future<void> _openCamera(BuildContext context, [Camera? camera]) async {
    final location = camera == null ? '/cameras/new' : '/cameras/${camera.id}';
    final changed = await context.push<bool>(location);
    if (!context.mounted || changed != true) return;
    await context.read<CameraListViewModel>().refresh();
  }

  Future<void> _refresh(BuildContext context) async {
    await Future.wait([
      context.read<CameraListViewModel>().refresh(),
      context.read<RecordingListViewModel>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cameras = context.watch<CameraListViewModel>();
    final recordings = context.watch<RecordingListViewModel>();
    if ((cameras.loading && !cameras.loaded) ||
        (recordings.loading && !recordings.loaded)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cameras.error != null && !cameras.loaded) {
      return AppErrorStateWidget(onRetry: cameras.load);
    }
    if (recordings.error != null && !recordings.loaded) {
      return AppErrorStateWidget(onRetry: recordings.load);
    }
    return DashboardOverview(
      cameras: cameras.items,
      recordings: recordings.items,
      onAdd: () => _openCamera(context),
      onEdit: (camera) => _openCamera(context, camera),
      onRefresh: () => _refresh(context),
    );
  }
}
