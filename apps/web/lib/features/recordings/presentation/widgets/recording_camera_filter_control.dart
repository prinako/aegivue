import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:flutter/material.dart';

typedef ApplyRecordingCameraFilter =
    Future<void> Function(Set<String> cameraIds);

class RecordingCameraFilterControl extends StatelessWidget {
  const RecordingCameraFilterControl({
    super.key,
    required this.cameras,
    required this.selectedCameraIds,
    required this.loading,
    this.error,
    required this.onApply,
    required this.onClear,
  });

  final List<Camera> cameras;
  final Set<String> selectedCameraIds;
  final bool loading;
  final Object? error;
  final ApplyRecordingCameraFilter onApply;
  final Future<void> Function() onClear;

  Future<void> _open(BuildContext context) async {
    final selection = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _RecordingCameraFilterDialog(
        cameras: cameras,
        selectedCameraIds: selectedCameraIds,
      ),
    );
    if (selection == null) return;
    if (selection.isEmpty || _selectsEveryCamera(selection)) {
      await onClear();
      return;
    }
    await onApply(selection);
  }

  bool _selectsEveryCamera(Set<String> selection) {
    if (cameras.isEmpty || selection.length != cameras.length) return false;
    return cameras.every((camera) => selection.contains(camera.id));
  }

  @override
  Widget build(BuildContext context) {
    final canOpen = cameras.isNotEmpty || selectedCameraIds.isNotEmpty;
    return OutlinedButton.icon(
      onPressed: canOpen ? () => _open(context) : null,
      icon: const Icon(Icons.videocam_outlined),
      label: Text(_label()),
    );
  }

  String _label() {
    if (selectedCameraIds.length > 1) {
      return '${selectedCameraIds.length} cameras';
    }
    if (selectedCameraIds.length == 1) {
      final selectedId = selectedCameraIds.single;
      for (final camera in cameras) {
        if (camera.id == selectedId) return camera.name;
      }
      return selectedId;
    }
    if (loading) return 'Loading cameras';
    if (error != null) return 'Camera filter unavailable';
    if (cameras.isEmpty) return 'No cameras';
    return 'All cameras';
  }
}

class _RecordingCameraFilterDialog extends StatefulWidget {
  const _RecordingCameraFilterDialog({
    required this.cameras,
    required this.selectedCameraIds,
  });

  final List<Camera> cameras;
  final Set<String> selectedCameraIds;

  @override
  State<_RecordingCameraFilterDialog> createState() =>
      _RecordingCameraFilterDialogState();
}

class _RecordingCameraFilterDialogState
    extends State<_RecordingCameraFilterDialog> {
  late Set<String> _selection;

  @override
  void initState() {
    super.initState();
    _selection = Set<String>.of(widget.selectedCameraIds);
  }

  void _toggle(String id, bool selected) {
    setState(() {
      if (selected) {
        _selection.add(id);
      } else {
        _selection.remove(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selection = widget.cameras.map((camera) => camera.id).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameras = [...widget.cameras]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final availableIds = cameras.map((camera) => camera.id).toSet();
    final missingIds = _selection.difference(availableIds).toList()..sort();

    return AlertDialog(
      title: const Text('Filter by camera'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final camera in cameras)
                CheckboxListTile(
                  value: _selection.contains(camera.id),
                  onChanged: (selected) =>
                      _toggle(camera.id, selected ?? false),
                  title: Text(camera.name),
                  subtitle: Text(_cameraStatus(camera)),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              for (final id in missingIds)
                CheckboxListTile(
                  value: true,
                  onChanged: (selected) => _toggle(id, selected ?? false),
                  title: Text('$id (unavailable)'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(<String>{}),
          child: const Text('Clear'),
        ),
        TextButton(onPressed: _selectAll, child: const Text('Select all')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selection),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

String _cameraStatus(Camera camera) {
  if (!camera.enabled) return 'Disabled';
  if (camera.runtimeState == 'online') return 'Online';
  return 'Offline';
}
