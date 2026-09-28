import 'package:aegivue/core/api/api_exception.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/camera_form_data.dart';
import 'package:aegivue/features/cameras/presentation/view_models/camera_editor_view_model.dart';
import 'package:aegivue/features/cameras/presentation/widgets/camera_connection_form_section.dart';
import 'package:aegivue/features/cameras/presentation/widgets/camera_details_form_section.dart';
import 'package:aegivue/features/cameras/presentation/widgets/camera_motion_form_section.dart';
import 'package:aegivue/features/cameras/presentation/widgets/camera_recording_form_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CameraSettingsPage extends StatefulWidget {
  static const id = 'cameras-sttings';
  const CameraSettingsPage({super.key, this.camera});

  final Camera? camera;

  @override
  State<CameraSettingsPage> createState() => _CameraSettingsPageState();
}

class _CameraSettingsPageState extends State<CameraSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final CameraFormData _formData;

  @override
  void initState() {
    super.initState();
    _formData = CameraFormData.fromCamera(widget.camera);
  }

  @override
  void dispose() {
    _formData.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_formData.missingMotionSubStream) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A sub stream is required for sub-stream motion analysis.',
          ),
        ),
      );
      return;
    }

    final viewModel = context.read<CameraEditorViewModel>();
    final saved = await viewModel.save(_formData.toConfiguration());
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }

    final error = viewModel.error;
    final message = error is ApiException
        ? error.message ?? 'Unable to save camera (${error.statusCode})'
        : 'Unable to save camera: $error';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.select<CameraEditorViewModel, bool>(
      (viewModel) => viewModel.saving,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_formData.editing ? 'Camera settings' : 'Add camera'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            CameraDetailsFormSection(data: _formData),
            const SizedBox(height: 24),
            CameraConnectionFormSection(data: _formData),
            const SizedBox(height: 24),
            CameraRecordingFormSection(data: _formData),
            const SizedBox(height: 24),
            CameraMotionFormSection(data: _formData),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(saving ? 'Saving…' : 'Save camera'),
            ),
          ],
        ),
      ),
    );
  }
}
