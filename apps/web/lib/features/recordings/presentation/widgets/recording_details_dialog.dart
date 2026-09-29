import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/widgets/selected_recording_card.dart';
import 'package:flutter/material.dart';

class RecordingDetailsDialog extends StatefulWidget {
  const RecordingDetailsDialog({
    super.key,
    required this.recording,
    this.onSetExpiry,
  });

  final Recording recording;
  final Future<bool> Function()? onSetExpiry;

  @override
  State<RecordingDetailsDialog> createState() => _RecordingDetailsDialogState();
}

class _RecordingDetailsDialogState extends State<RecordingDetailsDialog> {
  bool _updatingExpiry = false;

  Future<void> _setExpiry() async {
    final onSetExpiry = widget.onSetExpiry;
    if (_updatingExpiry || onSetExpiry == null) return;
    setState(() => _updatingExpiry = true);
    final updated = await onSetExpiry();
    if (!mounted) return;
    if (updated) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _updatingExpiry = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: SingleChildScrollView(
          child: SelectedRecordingCard(
            recording: widget.recording,
            onSetExpiry: widget.onSetExpiry == null ? null : _setExpiry,
            onClose: () => Navigator.of(context).pop(),
            updatingExpiry: _updatingExpiry,
          ),
        ),
      ),
    );
  }
}
