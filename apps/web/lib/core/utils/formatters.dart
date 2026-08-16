abstract final class Formatters {
  static String cameraState(String state) => state.isEmpty
      ? 'Unknown'
      : '${state[0].toUpperCase()}${state.substring(1)}';

  static String recordingTimestamp(DateTime value) {
    final time = value.toLocal();
    return '${_two(time.day)}/${_two(time.month)}/${time.year}  '
        '${_two(time.hour)}:${_two(time.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
