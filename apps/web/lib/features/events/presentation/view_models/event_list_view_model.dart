import 'package:aegivue/features/events/data/event_page.dart';
import 'package:aegivue/features/events/data/event_repository.dart';
import 'package:aegivue/features/events/domain/event.dart';
import 'package:flutter/foundation.dart';

class EventListViewModel extends ChangeNotifier {
  EventListViewModel(this._repository);

  static const int _pageSize = 25;

  final EventRepository _repository;
  List<AegivueEvent> _items = const [];
  bool _loading = false;
  bool _loaded = false;
  Object? _error;
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  int _reloadGeneration = 0;
  bool _disposed = false;

  List<AegivueEvent> get items => _items;
  bool get loading => _loading;
  bool get loaded => _loaded;
  Object? get error => _error;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;

  Future<void> load() => _reload();

  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    final generation = ++_reloadGeneration;
    _loading = true;
    _loadingMore = false;
    _error = null;
    _notifyListeners();
    try {
      final page = await _repository.listPage(
        page: 1,
        pageSize: _pageSize,
        kind: 'motion',
      );
      if (_disposed || generation != _reloadGeneration) return;
      _applyPage(page);
      _loaded = true;
    } catch (error) {
      if (_disposed || generation != _reloadGeneration) return;
      _error = error;
    } finally {
      if (generation == _reloadGeneration) {
        _loading = false;
        _notifyListeners();
      }
    }
  }

  void _applyPage(EventPage page) {
    _items = List<AegivueEvent>.unmodifiable(page.items);
    _page = page.page;
    _hasMore = page.hasMore;
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _reloadGeneration;
    _loadingMore = true;
    _error = null;
    _notifyListeners();
    try {
      final nextPage = await _repository.listPage(
        page: _page + 1,
        pageSize: _pageSize,
        kind: 'motion',
      );
      if (_disposed || generation != _reloadGeneration) return;
      final existingIds = _items.map((item) => item.id).toSet();
      _items = List<AegivueEvent>.unmodifiable([
        ..._items,
        ...nextPage.items.where((item) => !existingIds.contains(item.id)),
      ]);
      _page = nextPage.page;
      _hasMore = nextPage.hasMore;
    } catch (error) {
      if (_disposed || generation != _reloadGeneration) return;
      _error = error;
    } finally {
      if (generation == _reloadGeneration) {
        _loadingMore = false;
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
    _reloadGeneration++;
    super.dispose();
  }
}
