import 'dart:js_interop';

import 'package:aegivue/features/recordings/presentation/models/recording_playback.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class RecordingPlayerController {
  void Function()? _play;
  void Function()? _pause;
  void Function(double seconds)? _seek;
  void Function(bool muted)? _setMuted;
  void Function()? _toggleFullscreen;
  Object? _owner;

  void play() => _play?.call();
  void pause() => _pause?.call();
  void seek(Duration position) =>
      _seek?.call(position.inMicroseconds / Duration.microsecondsPerSecond);
  void setMuted(bool muted) => _setMuted?.call(muted);
  void toggleFullscreen() => _toggleFullscreen?.call();

  void _attach({
    required Object owner,
    required void Function() play,
    required void Function() pause,
    required void Function(double seconds) seek,
    required void Function(bool muted) setMuted,
    required void Function() toggleFullscreen,
  }) {
    _owner = owner;
    _play = play;
    _pause = pause;
    _seek = seek;
    _setMuted = setMuted;
    _toggleFullscreen = toggleFullscreen;
  }

  void _detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _play = null;
    _pause = null;
    _seek = null;
    _setMuted = null;
    _toggleFullscreen = null;
  }
}

class RecordingPlayer extends StatefulWidget {
  const RecordingPlayer({
    super.key,
    required this.playbackUrl,
    this.thumbnail = false,
    this.controller,
    this.initialPosition = Duration.zero,
    this.onPlaybackEvent,
    this.autoplay = false,
  });

  final String playbackUrl;
  final bool thumbnail;
  final RecordingPlayerController? controller;
  final Duration initialPosition;
  final ValueChanged<RecordingPlaybackEvent>? onPlaybackEvent;
  final bool autoplay;

  @override
  State<RecordingPlayer> createState() => _RecordingPlayerState();
}

class _RecordingPlayerState extends State<RecordingPlayer> {
  final Object _owner = Object();
  web.HTMLElement? _element;
  JSFunction? _eventListener;

  @override
  void didUpdateWidget(covariant RecordingPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(_owner);
      _bindController();
    }
  }

  @override
  void dispose() {
    final element = _element;
    final listener = _eventListener;
    if (element != null && listener != null) {
      element.removeEventListener('aegivue-playback', listener);
    }
    widget.controller?._detach(_owner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      key: ValueKey(
        '${widget.thumbnail ? 'thumb' : 'player'}-${widget.playbackUrl}',
      ),
      tagName: 'aegivue-recording-player',
      onElementCreated: (element) {
        element as web.HTMLElement;
        _element = element;
        element.setAttribute('src', widget.playbackUrl);
        element.setAttribute('mode', widget.thumbnail ? 'thumbnail' : 'player');
        element.style.width = '100%';
        element.style.height = '100%';
        element.style.display = 'block';
        element.style.pointerEvents = widget.thumbnail ? 'none' : 'auto';
        if (!widget.thumbnail && widget.onPlaybackEvent != null) {
          final listener = ((web.Event _) => _handlePlaybackEvent()).toJS;
          _eventListener = listener;
          element.addEventListener('aegivue-playback', listener);
        }
        _bindController();
        if (widget.initialPosition > Duration.zero) {
          widget.controller?.seek(widget.initialPosition);
        }
        if (widget.autoplay) widget.controller?.play();
      },
    );
  }

  void _bindController() {
    final element = _element;
    final controller = widget.controller;
    if (element == null || controller == null) return;
    final player = _AegivueRecordingPlayerElement._(element);
    controller._attach(
      owner: _owner,
      play: () => player.playMedia(),
      pause: () => player.pauseMedia(),
      seek: (seconds) => player.seekTo(seconds),
      setMuted: (muted) => player.setMuted(muted),
      toggleFullscreen: () => player.toggleFullscreen(),
    );
  }

  void _handlePlaybackEvent() {
    final element = _element;
    final callback = widget.onPlaybackEvent;
    if (element == null || callback == null) return;
    final phase = switch (element.getAttribute('playback-phase')) {
      'loading' => RecordingPlaybackPhase.loading,
      'ready' || 'seeked' => RecordingPlaybackPhase.ready,
      'playing' => RecordingPlaybackPhase.playing,
      'paused' => RecordingPlaybackPhase.paused,
      'ended' => RecordingPlaybackPhase.ended,
      'error' => RecordingPlaybackPhase.error,
      _ => RecordingPlaybackPhase.idle,
    };
    callback(
      RecordingPlaybackEvent(
        phase: phase,
        position: _seconds(element.getAttribute('current-time')),
        duration: _optionalSeconds(element.getAttribute('media-duration')),
        error: element.getAttribute('playback-error'),
      ),
    );
  }
}

Duration _seconds(String? value) => _optionalSeconds(value) ?? Duration.zero;

Duration? _optionalSeconds(String? value) {
  final seconds = double.tryParse(value ?? '');
  if (seconds == null || !seconds.isFinite || seconds < 0) return null;
  return Duration(
    microseconds: (seconds * Duration.microsecondsPerSecond).round(),
  );
}

@JS()
extension type _AegivueRecordingPlayerElement._(JSObject _)
    implements JSObject {
  external void playMedia();
  external void pauseMedia();
  external void seekTo(double seconds);
  external void setMuted(bool muted);
  external void toggleFullscreen();
}
