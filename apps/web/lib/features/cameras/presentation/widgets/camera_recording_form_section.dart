import 'package:aegivue/features/cameras/presentation/camera_form_data.dart';
import 'package:aegivue/features/cameras/presentation/camera_form_validators.dart';
import 'package:aegivue/features/cameras/presentation/widgets/camera_responsive_fields.dart';
import 'package:flutter/material.dart';

class CameraRecordingFormSection extends StatefulWidget {
  const CameraRecordingFormSection({super.key, required this.data});

  final CameraFormData data;

  @override
  State<CameraRecordingFormSection> createState() =>
      _CameraRecordingFormSectionState();
}

class _CameraRecordingFormSectionState
    extends State<CameraRecordingFormSection> {
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Recording', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Recording enabled'),
          value: data.recordingEnabled,
          onChanged: (value) => setState(() => data.recordingEnabled = value),
        ),
        DropdownButtonFormField<String>(
          initialValue: data.recordingMode,
          decoration: const InputDecoration(
            labelText: 'Recording mode',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'continuous', child: Text('Continuous')),
            DropdownMenuItem(value: 'motion', child: Text('Motion (planned)')),
          ],
          onChanged: (value) => setState(() => data.recordingMode = value!),
        ),
        const SizedBox(height: 12),
        CameraResponsiveFields(
          children: [
            TextFormField(
              controller: data.preEvent,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pre-event seconds',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  CameraFormValidators.integer(value, min: 0, max: 120),
            ),
            TextFormField(
              controller: data.postEvent,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Post-event seconds',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  CameraFormValidators.integer(value, min: 0, max: 600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: data.retentionDays,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Default retention days',
            hintText: '30',
            border: OutlineInputBorder(),
            helperText:
                'Leave blank to keep new recordings indefinitely. This default applies to newly finalized recordings; individual recording expiry can still be changed in the Recordings tab.',
            prefixIcon: Icon(Icons.auto_delete_outlined),
          ),
          validator: (value) =>
              CameraFormValidators.optionalInteger(value, min: 1, max: 3650),
        ),
      ],
    );
  }
}
