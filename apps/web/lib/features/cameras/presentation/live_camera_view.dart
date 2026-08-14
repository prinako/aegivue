import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class LiveCameraView extends StatelessWidget {
  const LiveCameraView({
    super.key,
    required this.cameraId,
    required this.online,
  });

  final String cameraId;
  final bool online;

  @override
  Widget build(BuildContext context) {
    if (!online) {
      return const ColoredBox(
        color: Color(0xFF080A0F),
        child: Center(
          child: Icon(
            Icons.videocam_off_outlined,
            color: Colors.white24,
            size: 42,
          ),
        ),
      );
    }

    return HtmlElementView.fromTagName(
      key: ValueKey('live-$cameraId'),
      tagName: 'vigilo-live-player',
      onElementCreated: (element) {
        element as web.HTMLElement;
        element.setAttribute('camera-id', cameraId);
        element.style.width = '100%';
        element.style.height = '100%';
        element.style.display = 'block';
        element.style.pointerEvents = 'none';
      },
    );
  }
}
