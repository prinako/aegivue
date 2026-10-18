import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/domain/recording_timeline_interval.dart';
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
  bool _selectionLoading = false;
  Object? _selectionError;
  int _requestGeneration = 0;
  int _selectionGeneration = 0;
  bool _disposed = false;

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

  Future<void> select(RecordingTimelineInterval interval) async {
    final generation = ++_selectionGeneration;
    _selectionLoading = true;
    _selectionError = null;
    _notifyListeners();
    try {
      final recording = await _repository.find(interval.recordingId);
      if (_disposed || generation != _selectionGeneration) return;
      _selectedRecording = recording;
    } catch (error) {
      if (_disposed || generation != _selectionGeneration) return;
      _selectionError = error;
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
    _selectionLoading = false;
    _selectionError = null;
    _notifyListeners();
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
    super.dispose();
  }
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
