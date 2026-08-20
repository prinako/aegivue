import 'package:aegivue/core/api/api_exception.dart';
import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:flutter/material.dart';

class CameraSettingsPage extends StatefulWidget {
  const CameraSettingsPage({super.key, required this.repository, this.camera});

  final CameraRepository repository;
  final Camera? camera;

  @override
  State<CameraSettingsPage> createState() => _CameraSettingsPageState();
}

class _CameraSettingsPageState extends State<CameraSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _mainStream;
  late final TextEditingController _subStream;
  late final TextEditingController _preEvent;
  late final TextEditingController _postEvent;
  late final TextEditingController _retentionDays;
  late final TextEditingController _motionFps;

  bool _enabled = true;
  bool _recordingEnabled = true;
  String _recordingMode = 'continuous';
  bool _motionEnabled = false;
  String _motionStream = 'sub';
  double _motionSensitivity = 0.65;
  bool _saving = false;
  bool _obscurePassword = true;

  bool get _editing => widget.camera != null;

  @override
  void initState() {
    super.initState();
    final camera = widget.camera;
    _id = TextEditingController(text: camera?.id ?? '');
    _name = TextEditingController(text: camera?.name ?? '');
    _host = TextEditingController(text: camera?.connection.host ?? '');
    _port = TextEditingController(text: '${camera?.connection.port ?? 554}');
    _username = TextEditingController(text: camera?.connection.username ?? '');
    _password = TextEditingController();
    _mainStream = TextEditingController(
      text: camera?.connection.mainStream ?? '',
    );
    _subStream = TextEditingController(
      text: camera?.connection.subStream ?? '',
    );
    _preEvent = TextEditingController(
      text: '${camera?.recording.preEventSeconds ?? 5}',
    );
    _postEvent = TextEditingController(
      text: '${camera?.recording.postEventSeconds ?? 15}',
    );
    _retentionDays = TextEditingController(
      text: camera?.recording.retentionDays?.toString() ?? '',
    );
    _motionFps = TextEditingController(text: '${camera?.motion.fps ?? 5}');
    _enabled = camera?.enabled ?? true;
    _recordingEnabled = camera?.recording.enabled ?? true;
    _recordingMode = camera?.recording.mode ?? 'continuous';
    _motionEnabled = camera?.motion.enabled ?? false;
    _motionStream = camera?.motion.stream ?? 'sub';
    _motionSensitivity = camera?.motion.sensitivity ?? 0.65;
  }

  @override
  void dispose() {
    for (final controller in [
      _id,
      _name,
      _host,
      _port,
      _username,
      _password,
      _mainStream,
      _subStream,
      _preEvent,
      _postEvent,
      _retentionDays,
      _motionFps,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  String? _stream(String? value) {
    final required = _required(value);
    if (required != null) return required;
    return value!.startsWith('/') ? null : 'Stream path must start with /';
  }

  String? _integer(String? value, {required int min, required int max}) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null) return 'Enter a number';
    if (parsed < min || parsed > max) return 'Use a value from $min to $max';
    return null;
  }

  String? _optionalInteger(String? value, {required int min, required int max}) {
    if (value == null || value.trim().isEmpty) return null;
    return _integer(value, min: min, max: max);
  }

  String? _fps(String? value) {
    final parsed = double.tryParse(value ?? '');
    if (parsed == null) return 'Enter a number';
    if (parsed < 0.1 || parsed > 30) return 'Use a value from 0.1 to 30';
    return null;
  }

  String? _cameraId(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final valid = RegExp(r'^[a-z0-9][a-z0-9_-]{2,63}$').hasMatch(value);
    return valid ? null : 'Use 3–64 lowercase letters, numbers, _ or -';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_motionEnabled &&
        _motionStream == 'sub' &&
        _subStream.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A sub stream is required for sub-stream motion analysis.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final retentionText = _retentionDays.text.trim();
      final configuration = CameraConfiguration(
        id: _id.text.trim(),
        name: _name.text.trim(),
        enabled: _enabled,
        host: _host.text.trim(),
        port: int.parse(_port.text),
        username: _username.text.trim().isEmpty ? null : _username.text.trim(),
        password: _password.text.isEmpty ? null : _password.text,
        mainStream: _mainStream.text.trim(),
        subStream: _subStream.text.trim().isEmpty
            ? null
            : _subStream.text.trim(),
        recordingEnabled: _recordingEnabled,
        recordingMode: _recordingMode,
        preEventSeconds: int.parse(_preEvent.text),
        postEventSeconds: int.parse(_postEvent.text),
        recordingRetentionDays:
            retentionText.isEmpty ? null : int.parse(retentionText),
        motionEnabled: _motionEnabled,
        motionStream: _motionStream,
        motionFps: double.parse(_motionFps.text),
        motionSensitivity: _motionSensitivity,
      );
      if (_editing) {
        await widget.repository.update(configuration);
      } else {
        await widget.repository.create(configuration);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to save camera (${error.statusCode})',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save camera: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_editing ? 'Camera settings' : 'Add camera')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _sectionTitle(context, 'Camera'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _id,
            enabled: !_editing,
            decoration: const InputDecoration(
              labelText: 'Camera ID',
              hintText: 'front-door',
              border: OutlineInputBorder(),
              helperText:
                  'Stable identifier used in storage paths and API URLs.',
            ),
            validator: _cameraId,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Front Door',
              border: OutlineInputBorder(),
            ),
            validator: _required,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            subtitle: const Text(
              'Enabled cameras are automatically kept running.',
            ),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'RTSP connection'),
          const SizedBox(height: 12),
          _responsiveFields([
            TextFormField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: 'Host / IP address',
                hintText: '192.168.30.10',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            TextFormField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'RTSP port',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _integer(value, min: 1, max: 65535),
            ),
          ]),
          const SizedBox(height: 12),
          _responsiveFields([
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            TextFormField(
              controller: _password,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: _editing ? 'New password' : 'Password',
                helperText: _editing
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
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _mainStream,
            decoration: const InputDecoration(
              labelText: 'Main stream path',
              hintText: '/Streaming/Channels/101',
              border: OutlineInputBorder(),
            ),
            validator: _stream,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _subStream,
            decoration: const InputDecoration(
              labelText: 'Sub stream path',
              hintText: '/Streaming/Channels/102',
              border: OutlineInputBorder(),
              helperText:
                  'Optional now; recommended for future motion analysis.',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              return _stream(value);
            },
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Recording'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recording enabled'),
            value: _recordingEnabled,
            onChanged: (value) => setState(() => _recordingEnabled = value),
          ),
          DropdownButtonFormField<String>(
            initialValue: _recordingMode,
            decoration: const InputDecoration(
              labelText: 'Recording mode',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'continuous', child: Text('Continuous')),
              DropdownMenuItem(
                value: 'motion',
                child: Text('Motion (planned)'),
              ),
            ],
            onChanged: (value) => setState(() => _recordingMode = value!),
          ),
          const SizedBox(height: 12),
          _responsiveFields([
            TextFormField(
              controller: _preEvent,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Pre-event seconds',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _integer(value, min: 0, max: 120),
            ),
            TextFormField(
              controller: _postEvent,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Post-event seconds',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _integer(value, min: 0, max: 600),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _retentionDays,
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
                _optionalInteger(value, min: 1, max: 3650),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Motion'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Motion detection'),
            subtitle: const Text(
              'Configuration is saved now; detection is a later Aegivue phase.',
            ),
            value: _motionEnabled,
            onChanged: (value) => setState(() => _motionEnabled = value),
          ),
          _responsiveFields([
            DropdownButtonFormField<String>(
              initialValue: _motionStream,
              decoration: const InputDecoration(
                labelText: 'Analysis stream',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'sub', child: Text('Sub stream')),
                DropdownMenuItem(value: 'main', child: Text('Main stream')),
              ],
              onChanged: (value) => setState(() => _motionStream = value!),
            ),
            TextFormField(
              controller: _motionFps,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Analysis FPS',
                border: OutlineInputBorder(),
              ),
              validator: _fps,
            ),
          ]),
          const SizedBox(height: 12),
          Text('Sensitivity: ${_motionSensitivity.toStringAsFixed(2)}'),
          Slider(
            value: _motionSensitivity,
            min: 0,
            max: 1,
            divisions: 20,
            label: _motionSensitivity.toStringAsFixed(2),
            onChanged: (value) => setState(() => _motionSensitivity = value),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving…' : 'Save camera'),
          ),
        ],
      ),
    ),
  );

  Widget _responsiveFields(List<Widget> fields) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 700) {
        return Column(
          children: [
            for (var index = 0; index < fields.length; index++) ...[
              fields[index],
              if (index != fields.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < fields.length; index++) ...[
            Expanded(child: fields[index]),
            if (index != fields.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    },
  );

  Widget _sectionTitle(BuildContext context, String title) =>
      Text(title, style: Theme.of(context).textTheme.titleLarge);
}
