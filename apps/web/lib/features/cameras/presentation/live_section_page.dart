import 'package:aegivue/features/cameras/presentation/live_view_page.dart';
import 'package:aegivue/features/cameras/presentation/view_models/camera_list_view_model.dart';
import 'package:aegivue/shared/widgets/app_error_state_widget.dart';
import 'package:aegivue/shared/widgets/app_inline_error_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LiveSectionPage extends StatelessWidget {
  const LiveSectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cameras = context.watch<CameraListViewModel>();
    if (cameras.loading && !cameras.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cameras.error != null && !cameras.loaded) {
      return AppErrorStateWidget(onRetry: cameras.load);
    }
    return Column(
      children: [
        if (cameras.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: AppInlineErrorWidget(
              message: 'Unable to refresh camera data',
              onRetry: cameras.refresh,
            ),
          ),
        Expanded(
          child: LiveViewPage(
            cameras: cameras.items,
            onRefresh: cameras.refresh,
          ),
        ),
      ],
    );
  }
}
