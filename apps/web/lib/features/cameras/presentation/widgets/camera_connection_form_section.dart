import 'package:aegivue/features/cameras/presentation/camera_form_data.dart';
import 'package:aegivue/features/cameras/presentation/camera_form_validators.dart';
import 'package:aegivue/features/cameras/presentation/widgets/camera_responsive_fields.dart';
import 'package:flutter/material.dart';

class CameraConnectionFormSection extends StatefulWidget {
  const CameraConnectionFormSection({super.key, required this.data});

  final CameraFormData data;

  @override
  State<CameraConnectionFormSection> createState() =>
      _CameraConnectionFormSectionState();
}

class _CameraConnectionFormSectionState
    extends State<CameraConnectionFormSection> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('RTSP connection', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        CameraResponsiveFields(
          children: [
            TextFormField(
              controller: data.host,
              decoration: const InputDecoration(
                labelText: 'Host / IP address',
                hintText: '192.168.30.10',
                border: OutlineInputBorder(),
              ),
              validator: CameraFormValidators.requiredText,
            ),
            TextFormField(
              controller: data.port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'RTSP port',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  CameraFormValidators.integer(value, min: 1, max: 65535),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CameraResponsiveFields(
          children: [
            TextFormField(
              controller: data.username,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            TextFormField(
              controller: data.password,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: data.editing ? 'New password' : 'Password',
                helperText: data.editing
                    ? 'Leave blank to keep the current password.'
                    : null,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: data.mainStream,
          decoration: const InputDecoration(
            labelText: 'Main stream path',
            hintText: '/Streaming/Channels/101',
            border: OutlineInputBorder(),
          ),
          validator: CameraFormValidators.stream,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: data.subStream,
          decoration: const InputDecoration(
            labelText: 'Sub stream path',
            hintText: '/Streaming/Channels/102',
            border: OutlineInputBorder(),
            helperText: 'Optional now; recommended for future motion analysis.',
          ),
          validator: CameraFormValidators.optionalStream,
        ),
      ],
    );
  }
}
