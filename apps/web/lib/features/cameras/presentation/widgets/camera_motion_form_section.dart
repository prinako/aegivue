import 'package:aegivue/features/cameras/presentation/camera_form_data.dart';
import 'package:aegivue/features/cameras/presentation/camera_form_validators.dart';
import 'package:aegivue/features/cameras/presentation/widgets/camera_responsive_fields.dart';
import 'package:flutter/material.dart';

class CameraMotionFormSection extends StatefulWidget {
  const CameraMotionFormSection({super.key, required this.data});

  final CameraFormData data;

  @override
  State<CameraMotionFormSection> createState() =>
      _CameraMotionFormSectionState();
}

class _CameraMotionFormSectionState extends State<CameraMotionFormSection> {
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Motion', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Motion detection'),
          subtitle: const Text(
            'Configuration is saved now; detection is a later Aegivue phase.',
          ),
          value: data.motionEnabled,
          onChanged: (value) => setState(() => data.motionEnabled = value),
        ),
        CameraResponsiveFields(
          children: [
            DropdownButtonFormField<String>(
              initialValue: data.motionStream,
              decoration: const InputDecoration(
                labelText: 'Analysis stream',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'sub', child: Text('Sub stream')),
                DropdownMenuItem(value: 'main', child: Text('Main stream')),
              ],
              onChanged: (value) => setState(() => data.motionStream = value!),
            ),
            TextFormField(
              controller: data.motionFps,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Analysis FPS',
                border: OutlineInputBorder(),
              ),
              validator: CameraFormValidators.fps,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Sensitivity: ${data.motionSensitivity.toStringAsFixed(2)}'),
        Slider(
          value: data.motionSensitivity,
          min: 0,
          max: 1,
          divisions: 20,
          label: data.motionSensitivity.toStringAsFixed(2),
          onChanged: (value) => setState(() => data.motionSensitivity = value),
        ),
      ],
    );
  }
}
