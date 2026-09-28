abstract final class CameraFormValidators {
  static String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  static String? stream(String? value) {
    final required = requiredText(value);
    if (required != null) return required;
    return value!.startsWith('/') ? null : 'Stream path must start with /';
  }

  static String? optionalStream(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return stream(value);
  }

  static String? integer(String? value, {required int min, required int max}) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null) return 'Enter a number';
    if (parsed < min || parsed > max) return 'Use a value from $min to $max';
    return null;
  }

  static String? optionalInteger(
    String? value, {
    required int min,
    required int max,
  }) {
    if (value == null || value.trim().isEmpty) return null;
    return integer(value, min: min, max: max);
  }

  static String? fps(String? value) {
    final parsed = double.tryParse(value ?? '');
    if (parsed == null) return 'Enter a number';
    if (parsed < 0.1 || parsed > 30) return 'Use a value from 0.1 to 30';
    return null;
  }

  static String? cameraId(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final valid = RegExp(r'^[a-z0-9][a-z0-9_-]{2,63}$').hasMatch(value);
    return valid ? null : 'Use 3–64 lowercase letters, numbers, _ or -';
  }
}
