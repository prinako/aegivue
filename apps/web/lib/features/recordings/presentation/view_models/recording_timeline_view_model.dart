import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/domain/recording_timeline_interval.dart';
import 'package:aegivue/features/recordings/presentation/models/recording_playback.dart';
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
    _dayStart = _startOfDay(_now());
  }

  final RecordingRepository _repository;
  final DateTime Function() _now;
  List<RecordingTimelineInterval> _items = const [];
  bool _loading = false;
  bool _loaded = false;
  Object? _error;
  late DateTime _dayStart;
  DateTime? _filterFrom;
  DateTime? _filterTo;
  Set<String> _cameraIds = const {};
  RecordingTimelineZoom _zoom = RecordingTimelineZoom.day;
  Recording? _selectedRecording;
  RecordingTimelineInterval? _selectedInterval;
  DateTime? _selectedTimestamp;
  bool _selectionLoading = false;
  Object? _selectionError;
  int _requestGeneration = 0;
  int _selectionGeneration = 0;
  bool _disposed = false;
  final ValueNotifier<RecordingPlaybackSnapshot> playback = ValueNotifier(
    const RecordingPlaybackSnapshot(),
  );

  List<RecordingTimelineInterval> get items => _items;
  bool get loading => _loading;
  bool get loaded => _loaded;
  Object? get error => _error;
  DateTime get dayStart => _dayStart;
  DateTime get dayEnd =>
      DateTime(_dayStart.year, _dayStart.month, _dayStart.day + 1);
  Set<String> get cameraIds => _cameraIds;
  RecordingTimelineZoom get zoom => _zoom;
  Recording? get selectedRecording => _selectedRecording;
  RecordingTimelineInterval? get selectedInterval => _selectedInterval;
  DateTime? get selectedTimestamp => _selectedTimestamp;
  DateTime? get noFootageTimestamp =>
      _selectedRecording == null && !_selectionLoading
      ? _selectedTimestamp
      : null;
  Duration get selectedOffset {
    final interval = _selectedInterval;
    final timestamp = _selectedTimestamp;
    if (interval == null || timestamp == null) return Duration.zero;
    final offset = timestamp.difference(interval.startTime);
    if (offset.isNegative) return Duration.zero;
    if (offset > interval.duration) return interval.duration;
    return offset;
  }

  DateTime? get playbackTimestamp {
    final interval = _selectedInterval;
    if (interval == null) return null;
    final position = playback.value.position > interval.duration
        ? interval.duration
        : playback.value.position;
    return interval.startTime.add(position);
  }

  RecordingTimelineInterval? get previousRecording => _adjacentRecording(-1);
  RecordingTimelineInterval? get nextRecording => _adjacentRecording(1);
  bool get selectionLoading => _selectionLoading;
  Object? get selectionError => _selectionError;

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
      return;
    }
    final localTo = to?.toLocal();
    if (localTo != null && localTo.isBefore(_startOfDay(_now()))) {
      _dayStart = _startOfDay(localTo);
    }
  }

  Future<void> refresh() => _reload();

  Future<void> previousDay() {
    _dayStart = DateTime(_dayStart.year, _dayStart.month, _dayStart.day - 1);
    return _reload();
  }

  Future<void> nextDay() {
    _dayStart = dayEnd;
    return _reload();
  }

  Future<void> today() {
    _dayStart = _startOfDay(_now());
    return _reload();
  }

  void setZoom(RecordingTimelineZoom zoom) {
    if (_zoom == zoom) return;
    _zoom = zoom;
    _notifyListeners();
  }

  Future<void> select(RecordingTimelineInterval interval) =>
      selectAt(interval, interval.startTime);

  Future<void> selectAt(
    RecordingTimelineInterval interval,
    DateTime timestamp,
  ) async {
    final generation = ++_selectionGeneration;
    _selectedInterval = interval;
    _selectedTimestamp = _clampTimestamp(timestamp, interval);
    _selectedRecording = null;
    _selectionLoading = true;
    _selectionError = null;
    playback.value = RecordingPlaybackSnapshot(
      phase: RecordingPlaybackPhase.loading,
      position: selectedOffset,
    );
    _notifyListeners();
    try {
      final recording = await _repository.find(interval.recordingId);
      if (_disposed || generation != _selectionGeneration) return;
      _selectedRecording = recording;
    } catch (error) {
      if (_disposed || generation != _selectionGeneration) return;
      _selectionError = error;
      playback.value = RecordingPlaybackSnapshot(
        phase: RecordingPlaybackPhase.error,
        error: error.toString(),
      );
    } finally {
      if (generation == _selectionGeneration) {
        _selectionLoading = false;
        _notifyListeners();
      }
    }
  }

  void clearSelection() {
    _selectionGeneration++;
    _selectedRecording = null;
    _selectedInterval = null;
    _selectedTimestamp = null;
    _selectionLoading = false;
    _selectionError = null;
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

  void markNoFootage(DateTime timestamp) {
    _selectionGeneration++;
    _selectedRecording = null;
    _selectedInterval = null;
    _selectedTimestamp = timestamp;
    _selectionLoading = false;
    _selectionError = null;
    playback.value = const RecordingPlaybackSnapshot();
    _notifyListeners();
  }

  void handlePlaybackEvent(String recordingId, RecordingPlaybackEvent event) {
    if (_selectedRecording?.id != recordingId) return;
    final interval = _selectedInterval;
    var position = event.position;
    if (position.isNegative) position = Duration.zero;
    final maximum = event.duration ?? interval?.duration;
    if (maximum != null && position > maximum) position = maximum;
    playback.value = RecordingPlaybackSnapshot(
      phase: event.phase,
      position: position,
      duration: event.duration,
      error: event.error,
    );
  }

  RecordingTimelineInterval? _adjacentRecording(int direction) {
    final selected = _selectedInterval;
    if (selected == null) return null;
    final recordings =
        _items.where((item) => item.cameraId == selected.cameraId).toList()
          ..sort((a, b) {
            final byStart = a.startTime.compareTo(b.startTime);
            if (byStart != 0) return byStart;
            final byEnd = a.endTime.compareTo(b.endTime);
            if (byEnd != 0) return byEnd;
            return a.recordingId.compareTo(b.recordingId);
          });
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
      _notifyListeners();
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
      final selectedId = _selectedInterval?.recordingId;
      if (selectedId != null &&
          !_items.any((item) => item.recordingId == selectedId)) {
        clearSelection();
      }
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
    _requestGeneration++;
    _selectionGeneration++;
    playback.dispose();
    super.dispose();
  }
}

DateTime _clampTimestamp(
  DateTime timestamp,
  RecordingTimelineInterval interval,
) {
  if (timestamp.isBefore(interval.startTime)) return interval.startTime;
  if (timestamp.isAfter(interval.endTime)) return interval.endTime;
  return timestamp;
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
