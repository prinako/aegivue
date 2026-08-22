import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/events/data/event_page.dart';
import 'package:aegivue/features/events/data/event_repository.dart';
import 'package:aegivue/features/events/domain/event.dart';
import 'package:flutter/foundation.dart';

class EventController extends ChangeNotifier {
  EventController(ApiClient api) : repository = EventRepository(api);

  static const int _pageSize = 25;

  final EventRepository repository;
  List<AegivueEvent> _items = const [];
  bool _loading = false;
  bool _loaded = false;
  Object? _error;
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;

  List<AegivueEvent> get items => _items;
  bool get loading => _loading;
  bool get loaded => _loaded;
  Object? get error => _error;
  bool get hasMore => _hasMore;
  bool get loadingMore => _loadingMore;

  Future<void> load() => _reload(showLoading: !_loaded);
  Future<void> refresh() => _reload(showLoading: false);

  Future<void> _reload({required bool showLoading}) async {
    if (showLoading) {
      _loading = true;
      notifyListeners();
    }
    _error = null;
    try {
      final page = await repository.listPage(
        page: 1,
        pageSize: _pageSize,
        kind: 'motion',
      );
      _applyPage(page);
      _loaded = true;
    } catch (error) {
      _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _applyPage(EventPage page) {
    _items = List<AegivueEvent>.unmodifiable(page.items);
    _page = page.page;
    _hasMore = page.hasMore;
  }

  Future<void> loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final nextPage = await repository.listPage(
        page: _page + 1,
        pageSize: _pageSize,
        kind: 'motion',
      );
      final existingIds = _items.map((item) => item.id).toSet();
      _items = List<AegivueEvent>.unmodifiable([
        ..._items,
        ...nextPage.items.where((item) => !existingIds.contains(item.id)),
      ]);
      _page = nextPage.page;
      _hasMore = nextPage.hasMore;
    } catch (error) {
      _error = error;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }
}
