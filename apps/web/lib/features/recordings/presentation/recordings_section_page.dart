import 'package:aegivue/features/cameras/presentation/view_models/camera_list_view_model.dart';
import 'package:aegivue/features/dashboard/presentation/view_models/app_header_actions_view_model.dart';
import 'package:aegivue/features/recordings/presentation/view_models/recording_list_view_model.dart';
import 'package:aegivue/features/recordings/presentation/view_models/recording_timeline_view_model.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_library.dart';
import 'package:aegivue/features/recordings/presentation/widgets/recording_header_actions.dart';
import 'package:aegivue/shared/widgets/app_error_state_widget.dart';
import 'package:aegivue/shared/widgets/app_inline_error_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecordingsSectionPage extends StatefulWidget {
  const RecordingsSectionPage({super.key});

  @override
  State<RecordingsSectionPage> createState() => _RecordingsSectionPageState();
}

class _RecordingsSectionPageState extends State<RecordingsSectionPage> {
  static const _section = 2;
  final Object _headerOwner = Object();
  AppHeaderActionsViewModel? _headerActions;
  RecordingLibraryView _view = RecordingLibraryView.grid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final headerActions = context.read<AppHeaderActionsViewModel>();
    if (identical(headerActions, _headerActions)) return;
    _headerActions?.unregister(section: _section, owner: _headerOwner);
    _headerActions = headerActions;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_headerActions, headerActions)) return;
      headerActions.register(
        section: _section,
        owner: _headerOwner,
        builder: _buildHeaderActions,
        onRefresh: _refresh,
      );
    });
  }

  Future<void> _refresh() => _view == RecordingLibraryView.timeline
      ? context.read<RecordingTimelineViewModel>().refresh()
      : context.read<RecordingListViewModel>().refresh();

  Widget _buildHeaderActions(BuildContext context) {
    final recordings = context.watch<RecordingListViewModel>();
    final cameras = context.watch<CameraListViewModel>();
    return RecordingHeaderActions(
      view: _view,
      onSelectView: _selectView,
      filterFrom: recordings.from,
      filterTo: recordings.to,
      onApplyDateFilter: _applyDateFilter,
      onClearDateFilter: _clearDateFilter,
      cameras: cameras.items,
      camerasLoading: cameras.loading && !cameras.loaded,
      cameraError: cameras.error,
      selectedCameraIds: recordings.cameraIds,
      onApplyCameraFilter: _applyCameraFilter,
      onClearCameraFilter: _clearCameraFilter,
    );
  }

  Future<void> _selectView(RecordingLibraryView view) async {
    if (_view == view) return;
    setState(() => _view = view);
    _headerActions?.refresh(_section);
    if (view != RecordingLibraryView.timeline) return;
    final recordings = context.read<RecordingListViewModel>();
    await context.read<RecordingTimelineViewModel>().load(
      filterFrom: recordings.from,
      filterTo: recordings.to,
      cameraIds: recordings.cameraIds,
    );
  }

  Future<void> _applyDateFilter({DateTime? from, DateTime? to}) async {
    await context.read<RecordingListViewModel>().applyDateFilter(
      from: from,
      to: to,
    );
    if (_view == RecordingLibraryView.timeline && mounted) {
      await context.read<RecordingTimelineViewModel>().syncFilters(
        filterFrom: from,
        filterTo: to,
        cameraIds: context.read<RecordingListViewModel>().cameraIds,
        focusDateFilter: true,
      );
    }
  }

  Future<void> _clearDateFilter() async {
    await context.read<RecordingListViewModel>().clearDateFilter();
    if (_view == RecordingLibraryView.timeline && mounted) {
      await context.read<RecordingTimelineViewModel>().syncFilters(
        cameraIds: context.read<RecordingListViewModel>().cameraIds,
      );
    }
  }

  Future<void> _applyCameraFilter(Set<String> cameraIds) async {
    final recordings = context.read<RecordingListViewModel>();
    await recordings.applyCameraFilter(cameraIds);
    if (_view == RecordingLibraryView.timeline && mounted) {
      await context.read<RecordingTimelineViewModel>().syncFilters(
        filterFrom: recordings.from,
        filterTo: recordings.to,
        cameraIds: cameraIds,
      );
    }
  }

  Future<void> _clearCameraFilter() async {
    final recordings = context.read<RecordingListViewModel>();
    await recordings.clearCameraFilter();
    if (_view == RecordingLibraryView.timeline && mounted) {
      await context.read<RecordingTimelineViewModel>().syncFilters(
        filterFrom: recordings.from,
        filterTo: recordings.to,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordings = context.watch<RecordingListViewModel>();
    final cameras = context.watch<CameraListViewModel>();
    final timeline = context.watch<RecordingTimelineViewModel>();
    if (recordings.loading && !recordings.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (recordings.error != null && !recordings.loaded) {
      return AppErrorStateWidget(onRetry: recordings.load);
    }
    return Column(
      children: [
        if (recordings.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: AppInlineErrorWidget(
              message: 'Unable to refresh recordings',
              onRetry: recordings.refresh,
            ),
          ),
        Expanded(
          child: RecordingLibrary(
            view: _view,
            recordings: recordings.items,
            onRefresh: recordings.refresh,
            onLoadMore: recordings.loadMore,
            onSetExpiry: recordings.setExpiry,
            hasMore: recordings.hasMore,
            loadingMore: recordings.loadingMore,
            updatingExpiry: recordings.updatingExpiry,
            filterFrom: recordings.from,
            filterTo: recordings.to,
            cameras: cameras.items,
            camerasLoading: cameras.loading && !cameras.loaded,
            cameraError: cameras.error,
            selectedCameraIds: recordings.cameraIds,
            timeline: timeline,
          ),
        ),
      ],
    );
  }
}
