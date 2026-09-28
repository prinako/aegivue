import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/events/data/event_page.dart';
import 'package:aegivue/features/events/data/event_repository.dart';
import 'package:aegivue/features/events/domain/event.dart';
import 'package:aegivue/features/events/presentation/view_models/event_list_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads motion events and exposes pagination state', () async {
    final repository = _FakeEventRepository()
      ..pages[1] = Future.value(_page(1, [_event('event-1')], totalPages: 2));
    final viewModel = EventListViewModel(repository);

    await viewModel.load();

    expect(viewModel.items.single.id, 'event-1');
    expect(viewModel.loaded, isTrue);
    expect(viewModel.hasMore, isTrue);
    expect(viewModel.error, isNull);
  });

  test('exposes a failed initial motion event load', () async {
    final failure = StateError('offline');
    final repository = _FakeEventRepository()..pages[1] = Future.error(failure);
    final viewModel = EventListViewModel(repository);

    await viewModel.load();

    expect(viewModel.loaded, isFalse);
    expect(viewModel.error, same(failure));
  });

  test('refresh replaces events and clears a previous error', () async {
    final repository = _FakeEventRepository()
      ..pages[1] = Future.error(StateError('offline'));
    final viewModel = EventListViewModel(repository);
    await viewModel.load();
    repository.pages[1] = Future.value(_page(1, [_event('event-2')]));

    await viewModel.refresh();

    expect(viewModel.items.single.id, 'event-2');
    expect(viewModel.loaded, isTrue);
    expect(viewModel.error, isNull);
  });

  test('loadMore appends unique events from the next page', () async {
    final repository = _FakeEventRepository()
      ..pages[1] = Future.value(
        _page(1, [_event('one'), _event('two')], totalPages: 2),
      )
      ..pages[2] = Future.value(
        _page(2, [_event('two'), _event('three')], totalPages: 2),
      );
    final viewModel = EventListViewModel(repository);
    await viewModel.load();

    await viewModel.loadMore();

    expect(viewModel.items.map((item) => item.id), ['one', 'two', 'three']);
    expect(viewModel.hasMore, isFalse);
  });

  test('successful pagination retry clears the previous error', () async {
    final failure = StateError('offline');
    final repository = _FakeEventRepository()
      ..pages[1] = Future.value(_page(1, [_event('one')], totalPages: 2))
      ..pages[2] = Future.error(failure);
    final viewModel = EventListViewModel(repository);
    await viewModel.load();
    await viewModel.loadMore();
    expect(viewModel.error, same(failure));
    repository.pages[2] = Future.value(
      _page(2, [_event('two')], totalPages: 2),
    );

    await viewModel.loadMore();

    expect(viewModel.error, isNull);
    expect(viewModel.items.map((item) => item.id), ['one', 'two']);
  });
}

class _FakeEventRepository extends EventRepository {
  _FakeEventRepository() : super(ApiClient());

  final Map<int, Future<EventPage>> pages = {};

  @override
  Future<EventPage> listPage({
    int page = 1,
    int pageSize = 25,
    String? kind,
    String? cameraId,
  }) => pages[page]!;
}

EventPage _page(int page, List<AegivueEvent> items, {int totalPages = 1}) =>
    EventPage(
      items: items,
      page: page,
      pageSize: 25,
      totalItems: items.length,
      totalPages: totalPages,
    );

AegivueEvent _event(String id) => AegivueEvent(
  id: id,
  cameraId: 'front-door',
  cameraName: 'Front Door',
  kind: 'motion',
  startedAt: DateTime.utc(2026, 9, 28),
  endedAt: null,
  score: 0.8,
  metadata: const {},
);
