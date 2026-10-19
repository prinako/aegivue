import 'dart:async';

import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/domain/recording_timeline_interval.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_camera_playback_session.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_playback.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_playback_command.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_playback_correction.dart';
import 'package:flutter/foundation.dart';

enum RecordingTimelineZoom {
  day(hours: 24, label: '24h'),
  sixHours(hours: 6, label: '6h'),
  oneHour(hours: 1, label: '1h');

  const RecordingTimelineZoom({required this.hours, required this.label});

  final int hours;
  final String label;
}

class RecordingTimelineViewModel extends ChangeNotifier {
  RecordingTimelineViewModel(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _dayStart = _startOfDay(_now().toLocal());
    _windowStart = _dayStart;
  }

  static const int maximumSimultaneousPlayers = 4;
  static const Duration driftTolerance = Duration(milliseconds: 750);

  final RecordingRepository _repository;
  final DateTime Function() _now;
  final Map<String, Recording> _recordingCache = {};
  List<RecordingTimelineInterval> _items = const [];
  bool _loading = false;
  bool _loaded = false;
  Object? _error;
  late DateTime _dayStart;
  late DateTime _windowStart;
  DateTime? _filterFrom;
  DateTime? _filterTo;
  Set<String> _cameraIds = const {};
  Set<String> _availableCameraIds = const {};
  RecordingTimelineZoom _zoom = RecordingTimelineZoom.day;
  Map<String, RecordingCameraPlaybackSession> _sessions = const {};
  DateTime? _sharedTimestampUtc;
  bool _playing = false;
  DateTime? _clockAnchorUtc;
  DateTime? _clockStartedUtc;
  Timer? _clockTimer;
  Object? _selectionError;
  int _requestGeneration = 0;
  int _selectionGeneration = 0;
  bool _disposed = false;

  final ValueNotifier<RecordingPlaybackSnapshot> playback = ValueNotifier(
    const RecordingPlaybackSnapshot(),
  );
  final ValueNotifier<Map<String, RecordingCameraPlaybackSession>>
  sessionsListenable = ValueNotifier(const {});
  final ValueNotifier<RecordingPlaybackCommand?> playbackCommand =
      ValueNotifier(null);
  final ValueNotifier<RecordingPlaybackCorrection?> playbackCorrection =
      ValueNotifier(null);

  List<RecordingTimelineInterval> get items => _items;
  bool get loading => _loading;
  bool get loaded => _loaded;
  Object? get error => _error;
  DateTime get dayStart => _dayStart;
  DateTime get dayEnd =>
      DateTime(_dayStart.year, _dayStart.month, _dayStart.day + 1);
  DateTime get windowStart =>
      _zoom == RecordingTimelineZoom.day ? _dayStart : _windowStart;
  DateTime get windowEnd => _zoom == RecordingTimelineZoom.day
      ? dayEnd
      : _windowStart.add(Duration(hours: _zoom.hours));
  Set<String> get cameraIds => _cameraIds;
  RecordingTimelineZoom get zoom => _zoom;
  Map<String, RecordingCameraPlaybackSession> get sessions => _sessions;
  List<String> get activeCameraIds => _activeCameraIds();
  DateTime? get sharedTimestamp => _sharedTimestampUtc;
  bool get playing => _playing;

  RecordingCameraPlaybackSession? get _primarySession {
    if (_sessions.isEmpty) return null;
    for (final cameraId in activeCameraIds) {
      final session = _sessions[cameraId];
      if (session?.hasFootage == true) return session;
    }
    return _sessions.values.first;
  }

  Recording? get selectedRecording => _primarySession?.recording;
  RecordingTimelineInterval? get selectedInterval => _primarySession?.interval;
  DateTime? get selectedTimestamp => _sharedTimestampUtc;
  DateTime? get noFootageTimestamp =>
      _sessions.isNotEmpty && _sessions.values.every((item) => !item.hasFootage)
      ? _sharedTimestampUtc
      : null;
  Duration get selectedOffset => _primarySession?.offset ?? Duration.zero;
  DateTime? get playbackTimestamp => _sharedTimestampUtc;
  RecordingTimelineInterval? get previousRecording => _adjacentRecording(-1);
  RecordingTimelineInterval? get nextRecording => _adjacentRecording(1);
  bool get selectionLoading => _sessions.values.any(
    (item) => item.phase == RecordingCameraSessionPhase.loading,
  );
  Object? get selectionError => _selectionError;

  void setAvailableCameraIds(Iterable<String> cameraIds) {
    _availableCameraIds = Set.unmodifiable(cameraIds);
  }

  Future<void> load({
    DateTime? filterFrom,
    DateTime? filterTo,
    Set<String> cameraIds = const {},
  }) {
    _filterFrom = filterFrom;
    _filterTo = filterTo;
    _cameraIds = Set.unmodifiable(cameraIds);
    _focusDateFilter(filterFrom, filterTo);
    return _reload();
  }

  Future<void> syncFilters({
    DateTime? filterFrom,
    DateTime? filterTo,
    Set<String> cameraIds = const {},
    bool focusDateFilter = false,
  }) {
    _filterFrom = filterFrom;
    _filterTo = filterTo;
    _cameraIds = Set.unmodifiable(cameraIds);
    if (focusDateFilter) _focusDateFilter(filterFrom, filterTo);
    return _reload();
  }

  void _focusDateFilter(DateTime? from, DateTime? to) {
    if (from != null) {
      _dayStart = _startOfDay(from.toLocal());
      _resetWindow();
      return;
    }
    final localTo = to?.toLocal();
    if (localTo != null && localTo.isBefore(_startOfDay(_now().toLocal()))) {
      _dayStart = _startOfDay(localTo);
      _resetWindow();
    }
  }

  Future<void> refresh() => _reload();

  Future<void> previousDay() {
    _dayStart = DateTime(_dayStart.year, _dayStart.month, _dayStart.day - 1);
    _resetWindow();
    clearSelection();
    return _reload();
  }

  Future<void> nextDay() {
    _dayStart = dayEnd;
    _resetWindow();
    clearSelection();
    return _reload();
  }

  Future<void> today() {
    _dayStart = _startOfDay(_now().toLocal());
    _resetWindow();
    return _reload();
  }

  void setZoom(RecordingTimelineZoom zoom) {
    if (_zoom == zoom) return;
    _zoom = zoom;
    _focusWindow(_sharedTimestampUtc?.toLocal() ?? _now().toLocal());
    _notifyListeners();
  }

  void previousWindow() => _moveWindow(-1);
  void nextWindow() => _moveWindow(1);

  Future<void> select(RecordingTimelineInterval interval) =>
      selectAt(interval, interval.startTime);

  Future<void> selectAt(
    RecordingTimelineInterval interval,
    DateTime timestamp,
  ) => seekTo(timestamp, preferredInterval: interval);

  Future<void> seekTo(
    DateTime timestamp, {
    RecordingTimelineInterval? preferredInterval,
  }) async {
    _sharedTimestampUtc = timestamp.toUtc();
    _clockAnchorUtc = _sharedTimestampUtc;
    _clockStartedUtc = _now().toUtc();
    _updateLegacyPlayback();
    await _resolveSessions(preferredInterval: preferredInterval);
    playbackCommand.value = RecordingPlaybackCommand(
      type: RecordingPlaybackCommandType.seek,
    );
  }

  Future<void> synchronize(DateTime timestamp) async {
    _sharedTimestampUtc = timestamp.toUtc();
    _updateSessionTimestamps();
    _updateLegacyPlayback();
    if (_sessionsNeedResolution()) await _resolveSessions();
  }

  void play() {
    if (_playing ||
        _sharedTimestampUtc == null ||
        !_sessions.values.any((session) => session.hasFootage)) {
      return;
    }
    _playing = true;
    _clockAnchorUtc = _sharedTimestampUtc;
    _clockStartedUtc = _now().toUtc();
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => unawaited(_tick()),
    );
    playbackCommand.value = const RecordingPlaybackCommand(
      type: RecordingPlaybackCommandType.play,
    );
    _updateLegacyPlayback();
  }

  void pause() {
    if (!_playing) return;
    _playing = false;
    _clockTimer?.cancel();
    _clockTimer = null;
    playbackCommand.value = const RecordingPlaybackCommand(
      type: RecordingPlaybackCommandType.pause,
    );
    _updateLegacyPlayback();
  }

  void clearSelection() {
    _selectionGeneration++;
    pause();
    _sessions = const {};
    _sharedTimestampUtc = null;
    _selectionError = null;
    sessionsListenable.value = const {};
    playback.value = const RecordingPlaybackSnapshot();
    _notifyListeners();
  }

  Future<void> selectPrevious() async {
    final interval = previousRecording;
    if (interval != null) await select(interval);
  }

  Future<void> selectNext() async {
    final interval = nextRecording;
    if (interval != null) await select(interval);
  }

  void markNoFootage(DateTime timestamp) => unawaited(seekTo(timestamp));

  void handlePlaybackEvent(String recordingId, RecordingPlaybackEvent event) {
    final entry = _sessions.entries.where(
      (item) => item.value.recording?.id == recordingId,
    );
    if (entry.isEmpty) return;
    handleCameraPlaybackEvent(entry.first.key, recordingId, event);
  }

  void handleCameraPlaybackEvent(
    String cameraId,
    String recordingId,
    RecordingPlaybackEvent event,
  ) {
    final session = _sessions[cameraId];
    if (session == null || session.recording?.id != recordingId) return;
    final phase = event.phase == RecordingPlaybackPhase.error
        ? RecordingCameraSessionPhase.error
        : session.phase;
    final shouldPublishSession =
        phase != session.phase ||
        event.phase != session.playback.phase ||
        event.error != session.error;
    _sessions = Map.unmodifiable({
      ..._sessions,
      cameraId: session.copyWith(
        phase: phase,
        playback: RecordingPlaybackSnapshot(
          phase: event.phase,
          position: event.position,
          duration: event.duration,
          error: event.error,
        ),
        error: event.error,
      ),
    });
    if (shouldPublishSession) sessionsListenable.value = _sessions;
    final interval = session.interval;
    final timestamp = _sharedTimestampUtc;
    if (interval == null || timestamp == null) return;
    if (event.phase == RecordingPlaybackPhase.ended && !_playing) {
      _updateLegacyPlayback();
      return;
    }
    if (event.phase == RecordingPlaybackPhase.ended) {
      final boundary = interval.endTime.toUtc();
      _clockAnchorUtc = boundary;
      _clockStartedUtc = _now().toUtc();
      unawaited(synchronize(boundary));
      return;
    }
    if (!_playing) {
      _sharedTimestampUtc = interval.startTime.add(event.position).toUtc();
      _updateSessionTimestamps();
      sessionsListenable.value = _sessions;
      _updateLegacyPlayback();
      return;
    }
    if (event.phase != RecordingPlaybackPhase.playing) return;
    final expected = timestamp.difference(interval.startTime);
    final drift = (event.position - expected).abs();
    if (drift > driftTolerance) {
      playbackCorrection.value = RecordingPlaybackCorrection(
        cameraId: cameraId,
        position: expected.isNegative ? Duration.zero : expected,
      );
    }
  }

  Future<void> _tick() async {
    final anchor = _clockAnchorUtc;
    final started = _clockStartedUtc;
    if (!_playing || anchor == null || started == null) return;
    final timestamp = anchor.add(_now().toUtc().difference(started));
    if (!timestamp.isBefore(dayEnd.toUtc())) {
      await synchronize(dayEnd.toUtc());
      pause();
      return;
    }
    await synchronize(timestamp);
  }

  Future<void> _resolveSessions({
    RecordingTimelineInterval? preferredInterval,
  }) async {
    final timestamp = _sharedTimestampUtc;
    if (timestamp == null) return;
    final generation = ++_selectionGeneration;
    _selectionError = null;
    final cameraIds = _activeCameraIds().toSet();
    if (preferredInterval != null) cameraIds.add(preferredInterval.cameraId);
    final pending = <String, RecordingCameraPlaybackSession>{};
    for (final cameraId in cameraIds) {
      final interval = _intervalForCamera(
        cameraId,
        timestamp,
        preferredInterval: preferredInterval,
      );
      final existing = _sessions[cameraId];
      if (interval != null &&
          existing?.interval?.recordingId == interval.recordingId &&
          existing?.recording != null) {
        pending[cameraId] = existing!.copyWith(timestamp: timestamp);
      } else {
        pending[cameraId] = RecordingCameraPlaybackSession(
          cameraId: cameraId,
          timestamp: timestamp,
          phase: interval == null
              ? RecordingCameraSessionPhase.noFootage
              : RecordingCameraSessionPhase.loading,
          interval: interval,
        );
      }
    }
    if (_playing &&
        pending.values.every(
          (session) => session.phase == RecordingCameraSessionPhase.noFootage,
        )) {
      pause();
    }
    _sessions = Map.unmodifiable(pending);
    sessionsListenable.value = _sessions;
    _notifyListeners();

    await Future.wait([
      for (final entry in pending.entries)
        if (entry.value.phase == RecordingCameraSessionPhase.loading)
          if (entry.value.interval case final interval?)
            _loadSession(entry.key, interval, timestamp, generation),
    ]);
    if (_disposed || generation != _selectionGeneration) return;
    _updateLegacyPlayback();
    _notifyListeners();
  }

  Future<void> _loadSession(
    String cameraId,
    RecordingTimelineInterval interval,
    DateTime timestamp,
    int generation,
  ) async {
    try {
      final recording =
          _recordingCache[interval.recordingId] ??
          await _repository.find(interval.recordingId);
      if (_disposed || generation != _selectionGeneration) return;
      _recordingCache[recording.id] = recording;
      _replaceSession(
        cameraId,
        RecordingCameraPlaybackSession(
          cameraId: cameraId,
          timestamp: timestamp,
          phase: RecordingCameraSessionPhase.ready,
          interval: interval,
          recording: recording,
          playback: RecordingPlaybackSnapshot(
            phase: RecordingPlaybackPhase.loading,
            position: timestamp.difference(interval.startTime),
          ),
        ),
      );
    } catch (error) {
      if (_disposed || generation != _selectionGeneration) return;
      _selectionError ??= error;
      _replaceSession(
        cameraId,
        RecordingCameraPlaybackSession(
          cameraId: cameraId,
          timestamp: timestamp,
          phase: RecordingCameraSessionPhase.error,
          interval: interval,
          error: error.toString(),
        ),
      );
    }
  }

  void _replaceSession(
    String cameraId,
    RecordingCameraPlaybackSession session,
  ) {
    _sessions = Map.unmodifiable({..._sessions, cameraId: session});
    sessionsListenable.value = _sessions;
  }

  RecordingTimelineInterval? _intervalForCamera(
    String cameraId,
    DateTime timestamp, {
    RecordingTimelineInterval? preferredInterval,
  }) {
    if (preferredInterval?.cameraId == cameraId &&
        _contains(preferredInterval!, timestamp)) {
      return preferredInterval;
    }
    final matches =
        _items
            .where(
              (item) => item.cameraId == cameraId && _contains(item, timestamp),
            )
            .toList()
          ..sort(_compareIntervals);
    return matches.isEmpty ? null : matches.first;
  }

  bool _sessionsNeedResolution() {
    final timestamp = _sharedTimestampUtc;
    if (timestamp == null) return false;
    final cameraIds = _activeCameraIds();
    if (!_sessions.keys.toSet().containsAll(cameraIds) ||
        !cameraIds.toSet().containsAll(_sessions.keys)) {
      return true;
    }
    for (final cameraId in cameraIds) {
      final desired = _intervalForCamera(cameraId, timestamp);
      if (_sessions[cameraId]?.interval?.recordingId != desired?.recordingId) {
        return true;
      }
    }
    return false;
  }

  void _updateSessionTimestamps() {
    final timestamp = _sharedTimestampUtc;
    if (timestamp == null || _sessions.isEmpty) return;
    _sessions = Map.unmodifiable({
      for (final entry in _sessions.entries)
        entry.key: entry.value.copyWith(timestamp: timestamp),
    });
  }

  void _updateLegacyPlayback() {
    final session = _primarySession;
    playback.value = RecordingPlaybackSnapshot(
      phase: _playing
          ? RecordingPlaybackPhase.playing
          : session?.playback.phase ?? RecordingPlaybackPhase.idle,
      position: session?.offset ?? Duration.zero,
      duration: session?.playback.duration,
      error: session?.error,
    );
  }

  List<String> _activeCameraIds() {
    final source = _cameraIds.isNotEmpty
        ? _cameraIds
        : _availableCameraIds.isNotEmpty
        ? _availableCameraIds
        : _items.map((item) => item.cameraId).toSet();
    final sorted = source.toList()..sort();
    return List.unmodifiable(sorted.take(maximumSimultaneousPlayers));
  }

  void _focusWindow(DateTime focus) {
    if (_zoom == RecordingTimelineZoom.day) {
      _windowStart = _dayStart;
      return;
    }
    final hours = _zoom.hours;
    final alignedHour = (focus.hour ~/ hours) * hours;
    var start = DateTime(focus.year, focus.month, focus.day, alignedHour);
    final latest = dayEnd.subtract(Duration(hours: hours));
    if (start.isBefore(_dayStart)) start = _dayStart;
    if (start.isAfter(latest)) start = latest;
    _windowStart = start;
  }

  void _moveWindow(int direction) {
    if (_zoom == RecordingTimelineZoom.day) return;
    final duration = Duration(hours: _zoom.hours);
    final latest = dayEnd.subtract(duration);
    var target = _windowStart.add(duration * direction);
    if (target.isBefore(_dayStart)) target = _dayStart;
    if (target.isAfter(latest)) target = latest;
    if (target == _windowStart) return;
    _windowStart = target;
    _notifyListeners();
  }

  void _resetWindow() {
    _windowStart = _dayStart;
  }

  RecordingTimelineInterval? _adjacentRecording(int direction) {
    final selected = selectedInterval;
    if (selected == null) return null;
    final recordings =
        _items.where((item) => item.cameraId == selected.cameraId).toList()
          ..sort(_compareIntervals);
    final index = recordings.indexWhere(
      (item) => item.recordingId == selected.recordingId,
    );
    final target = index + direction;
    if (index < 0 || target < 0 || target >= recordings.length) return null;
    return recordings[target];
  }

  Future<void> _reload() async {
    final generation = ++_requestGeneration;
    final from = _later(_dayStart, _filterFrom);
    final to = _earlier(dayEnd, _filterTo);
    _loading = true;
    _error = null;
    _notifyListeners();
    if (!from.isBefore(to)) {
      _items = const [];
      _loaded = true;
      _loading = false;
      clearSelection();
      return;
    }
    try {
      final items = await _repository.timeline(
        from: from,
        to: to,
        cameraIds: _cameraIds,
      );
      if (_disposed || generation != _requestGeneration) return;
      _items = List.unmodifiable(items);
      _loaded = true;
      if (_sharedTimestampUtc != null) await _resolveSessions();
    } catch (error) {
      if (_disposed || generation != _requestGeneration) return;
      _error = error;
    } finally {
      if (generation == _requestGeneration) {
        _loading = false;
        _notifyListeners();
      }
    }
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clockTimer?.cancel();
    _requestGeneration++;
    _selectionGeneration++;
    playback.dispose();
    sessionsListenable.dispose();
    playbackCommand.dispose();
    playbackCorrection.dispose();
    super.dispose();
  }
}

bool _contains(RecordingTimelineInterval interval, DateTime timestamp) =>
    !timestamp.isBefore(interval.startTime) &&
    timestamp.isBefore(interval.endTime);

int _compareIntervals(
  RecordingTimelineInterval first,
  RecordingTimelineInterval second,
) {
  final start = first.startTime.compareTo(second.startTime);
  if (start != 0) return start;
  final end = first.endTime.compareTo(second.endTime);
  if (end != 0) return end;
  return first.recordingId.compareTo(second.recordingId);
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _later(DateTime dayBound, DateTime? filterBound) {
  if (filterBound == null || dayBound.isAfter(filterBound)) return dayBound;
  return filterBound;
}

DateTime _earlier(DateTime dayBound, DateTime? filterBound) {
  if (filterBound == null || dayBound.isBefore(filterBound)) return dayBound;
  return filterBound;
}
