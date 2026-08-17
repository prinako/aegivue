import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class RecordingPlayer extends StatelessWidget {
  const RecordingPlayer({
    super.key,
    required this.playbackUrl,
    this.thumbnail = false,
  });

  final String playbackUrl;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      key: ValueKey('${thumbnail ? 'thumb' : 'player'}-$playbackUrl'),
      tagName: 'aegivue-recording-player',
      onElementCreated: (element) {
        element as web.HTMLElement;
        element.setAttribute('src', playbackUrl);
        element.setAttribute('mode', thumbnail ? 'thumbnail' : 'player');
        element.style.width = '100%';
        element.style.height = '100%';
        element.style.display = 'block';
        element.style.pointerEvents = thumbnail ? 'none' : 'auto';
      },
    );
  }
}
