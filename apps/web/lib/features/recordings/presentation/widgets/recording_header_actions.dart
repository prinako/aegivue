import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_camera_filter_control.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_date_filter_control.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_library.dart';
import 'package:flutter/material.dart';

class RecordingHeaderActions extends StatelessWidget {
  const RecordingHeaderActions({
    super.key,
    required this.view,
    required this.onSelectView,
    required this.filterFrom,
    required this.filterTo,
    required this.onApplyDateFilter,
    required this.onClearDateFilter,
    required this.cameras,
    required this.camerasLoading,
    required this.cameraError,
    required this.selectedCameraIds,
    required this.onApplyCameraFilter,
    required this.onClearCameraFilter,
  });

  final RecordingLibraryView view;
  final ValueChanged<RecordingLibraryView> onSelectView;
  final DateTime? filterFrom;
  final DateTime? filterTo;
  final ApplyRecordingDateFilter onApplyDateFilter;
  final Future<void> Function() onClearDateFilter;
  final List<Camera> cameras;
  final bool camerasLoading;
  final Object? cameraError;
  final Set<String> selectedCameraIds;
  final ApplyRecordingCameraFilter onApplyCameraFilter;
  final Future<void> Function() onClearCameraFilter;

  @override
  Widget build(BuildContext context) {
    final date = RecordingDateFilterControl(
      from: filterFrom,
      to: filterTo,
      onApply: onApplyDateFilter,
      onClear: onClearDateFilter,
    );
    final camerasControl = RecordingCameraFilterControl(
      cameras: cameras,
      selectedCameraIds: selectedCameraIds,
      loading: camerasLoading,
      error: cameraError,
      onApply: onApplyCameraFilter,
      onClear: onClearCameraFilter,
    );
    final viewControl = SegmentedButton<RecordingLibraryView>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: RecordingLibraryView.grid,
          icon: Icon(Icons.grid_view_rounded),
          label: Text('Grid'),
        ),
        ButtonSegment(
          value: RecordingLibraryView.timeline,
          icon: Icon(Icons.timeline_rounded),
          label: Text('Timeline'),
        ),
      ],
      selected: {view},
      onSelectionChanged: (selection) => onSelectView(selection.single),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 420;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (narrow) ...[viewControl, const SizedBox(width: 8)],
              date,
              const SizedBox(width: 8),
              camerasControl,
              if (!narrow) ...[const SizedBox(width: 8), viewControl],
            ],
          ),
        );
      },
    );
  }
}
