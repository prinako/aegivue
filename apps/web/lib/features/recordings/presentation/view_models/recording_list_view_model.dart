import 'package:aegivue/features/recordings/data/recording_page.dart';
import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:flutter/foundation.dart';

class RecordingListViewModel extends ChangeNotifier {
  RecordingListViewModel(this._repository);

  static const int _pageSize = 25;

  final RecordingRepository _repository;
  List<Recording> _items = const [];
  bool _loading = false;
  bool _loaded = false;
  Object? _error;
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _updatingExpiry = false;
  Object? _expiryError;
  int _reloadGeneration = 0;

  List<Recording> get items => _items;
  bool get loading => _loading;
  bool get loaded => _loaded;
  Object? get error => _error;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;
  bool get updatingExpiry => _updatingExpiry;
  Object? get expiryError => _expiryError;

  Future<void> load() => _reload();

  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    final generation = ++_reloadGeneration;
    _loading = true;
    _loadingMore = false;
    _error = null;
    notifyListeners();
    try {
      final page = await _repository.listPage(page: 1, pageSize: _pageSize);
      if (generation != _reloadGeneration) return;
      _applyPage(page);
      _loaded = true;
    } catch (error) {
      if (generation != _reloadGeneration) return;
      _error = error;
    } finally {
      if (generation == _reloadGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void _applyPage(RecordingPage page) {
    _items = List<Recording>.unmodifiable(page.items);
    _page = page.page;
    _hasMore = page.hasMore;
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _reloadGeneration;
    _loadingMore = true;
    _error = null;
    notifyListeners();
    try {
      final nextPage = await _repository.listPage(
        page: _page + 1,
        pageSize: _pageSize,
      );
      if (generation != _reloadGeneration) return;
      final existingIds = _items.map((item) => item.id).toSet();
      _items = List<Recording>.unmodifiable([
        ..._items,
        ...nextPage.items.where((item) => !existingIds.contains(item.id)),
      ]);
      _page = nextPage.page;
      _hasMore = nextPage.hasMore;
    } catch (error) {
      if (generation != _reloadGeneration) return;
      _error = error;
    } finally {
      if (generation == _reloadGeneration) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> setExpiry(Recording recording, DateTime? expiresAt) async {
    if (_updatingExpiry) return;
    _updatingExpiry = true;
    _expiryError = null;
    notifyListeners();

    try {
      final updated = await _repository.setExpiry(recording.id, expiresAt);
      final items = [..._items];
      final index = items.indexWhere((item) => item.id == updated.id);
      if (index != -1) {
        items[index] = updated;
        _items = List<Recording>.unmodifiable(items);
      }
    } catch (error) {
      _expiryError = error;
      rethrow;
    } finally {
      _updatingExpiry = false;
      notifyListeners();
    }
  }
}
