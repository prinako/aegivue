import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:web/web.dart' as web;

abstract final class RecordingDownload {
  static void start(Recording recording) {
    final anchor = web.HTMLAnchorElement()
      ..href = recording.playbackUrl
      ..download = _fileName(recording);

    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  static String _fileName(Recording recording) {
    final local = recording.startTime.toLocal();
    final timestamp = [
      local.year.toString().padLeft(4, '0'),
      local.month.toString().padLeft(2, '0'),
      local.day.toString().padLeft(2, '0'),
      local.hour.toString().padLeft(2, '0'),
      local.minute.toString().padLeft(2, '0'),
      local.second.toString().padLeft(2, '0'),
    ].join('-');
    final camera = recording.cameraId.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
    final extension = recording.container.toLowerCase();
    return 'aegivue-$camera-$timestamp.$extension';
  }
}
