import 'package:aegivue/features/cameras/presentation/camera_form_data.dart';
import 'package:aegivue/features/cameras/presentation/camera_form_validators.dart';
import 'package:flutter/material.dart';

class CameraDetailsFormSection extends StatefulWidget {
  const CameraDetailsFormSection({super.key, required this.data});

  final CameraFormData data;

  @override
  State<CameraDetailsFormSection> createState() =>
      _CameraDetailsFormSectionState();
}

class _CameraDetailsFormSectionState extends State<CameraDetailsFormSection> {
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Camera', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(
          controller: data.id,
          enabled: !data.editing,
          decoration: const InputDecoration(
            labelText: 'Camera ID',
            hintText: 'front-door',
            border: OutlineInputBorder(),
            helperText: 'Stable identifier used in storage paths and API URLs.',
          ),
          validator: CameraFormValidators.cameraId,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: data.name,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Front Door',
            border: OutlineInputBorder(),
          ),
          validator: CameraFormValidators.requiredText,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enabled'),
          subtitle: const Text(
            'Enabled cameras are automatically kept running.',
          ),
          value: data.enabled,
          onChanged: (value) => setState(() => data.enabled = value),
        ),
      ],
    );
  }
}
