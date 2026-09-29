import 'dart:async';

import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/recordings/data/recording_page.dart';
import 'package:aegivue/features/recordings/data/recording_repository.dart';
import 'package:aegivue/features/recordings/domain/recording.dart';
import 'package:aegivue/features/recordings/presentation/view_models/recording_list_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initial load exposes loading then the first page', () async {
    final pending = Completer<RecordingPage>();
    final repository = _FakeRecordingRepository()..pages[1] = pending.future;
    final viewModel = RecordingListViewModel(repository);

    final load = viewModel.load();

    expect(viewModel.loading, isTrue);
    pending.complete(_page(1, [_recording('recording-1')], totalPages: 2));
    await load;
    expect(viewModel.items.single.id, 'recording-1');
    expect(viewModel.loaded, isTrue);
    expect(viewModel.hasMore, isTrue);
    expect(viewModel.error, isNull);
  });

  test('initial load exposes failure without marking data loaded', () async {
    final failure = StateError('offline');
    final repository = _FakeRecordingRepository()
      ..pages[1] = Future.error(failure);
    final viewModel = RecordingListViewModel(repository);

    await viewModel.load();

    expect(viewModel.loading, isFalse);
    expect(viewModel.loaded, isFalse);
    expect(viewModel.error, same(failure));
  });

  test('refresh replaces loaded items with the first page', () async {
    final repository = _FakeRecordingRepository()
      ..pages[1] = Future.value(_page(1, [_recording('old')]));
    final viewModel = RecordingListViewModel(repository);
    await viewModel.load();
    repository.pages[1] = Future.value(_page(1, [_recording('new')]));

    await viewModel.refresh();

    expect(viewModel.items.map((item) => item.id), ['new']);
  });

  test('exposes the server total independently of loaded items', () async {
    final repository = _FakeRecordingRepository()
      ..pages[1] = Future.value(
        _page(1, [_recording('one')], totalItems: 42, totalPages: 2),
      );
    final viewModel = RecordingListViewModel(repository);

    await viewModel.load();

    expect(viewModel.totalItems, 42);
  });

  test('an older load cannot overwrite a newer refresh', () async {
    final first = Completer<RecordingPage>();
    final repository = _FakeRecordingRepository()..pages[1] = first.future;
    final viewModel = RecordingListViewModel(repository);

    final initialLoad = viewModel.load();
    repository.pages[1] = Future.value(_page(1, [_recording('new')]));
    await viewModel.refresh();
    first.complete(_page(1, [_recording('old')]));
    await initialLoad;

    expect(viewModel.items.single.id, 'new');
  });

  test('a pending load completes safely after disposal', () async {
    final pending = Completer<RecordingPage>();
    final repository = _FakeRecordingRepository()..pages[1] = pending.future;
    final viewModel = RecordingListViewModel(repository);

    final loading = viewModel.load();
    viewModel.dispose();
    pending.complete(_page(1, [_recording('recording-1')]));

    await expectLater(loading, completes);
  });

  test('refresh invalidates an in-flight pagination response', () async {
    final nextPage = Completer<RecordingPage>();
    final repository = _FakeRecordingRepository()
      ..pages[1] = Future.value(
        _page(1, [_recording('old-first')], totalPages: 2),
      )
      ..pages[2] = nextPage.future;
    final viewModel = RecordingListViewModel(repository);
    await viewModel.load();

    final pagination = viewModel.loadMore();
    repository.pages[1] = Future.value(_page(1, [_recording('new-first')]));
    await viewModel.refresh();
    nextPage.complete(_page(2, [_recording('old-second')], totalPages: 2));
    await pagination;

    expect(viewModel.items.map((item) => item.id), ['new-first']);
  });

  test('loadMore appends the next page without duplicate recordings', () async {
    final repository = _FakeRecordingRepository()
      ..pages[1] = Future.value(
        _page(1, [_recording('one'), _recording('two')], totalPages: 2),
      )
      ..pages[2] = Future.value(
        _page(2, [_recording('two'), _recording('three')], totalPages: 2),
      );
    final viewModel = RecordingListViewModel(repository);
    await viewModel.load();

    await viewModel.loadMore();

    expect(viewModel.items.map((item) => item.id), ['one', 'two', 'three']);
    expect(viewModel.hasMore, isFalse);
    expect(viewModel.loadingMore, isFalse);
  });

  test('successful pagination retry clears the previous error', () async {
    final failure = StateError('offline');
    final repository = _FakeRecordingRepository()
      ..pages[1] = Future.value(_page(1, [_recording('one')], totalPages: 2))
      ..pages[2] = Future.error(failure);
    final viewModel = RecordingListViewModel(repository);
    await viewModel.load();
    await viewModel.loadMore();
    expect(viewModel.error, same(failure));
    repository.pages[2] = Future.value(
      _page(2, [_recording('two')], totalPages: 2),
    );

    await viewModel.loadMore();

    expect(viewModel.error, isNull);
    expect(viewModel.items.map((item) => item.id), ['one', 'two']);
  });

  test('setExpiry replaces the matching recording', () async {
    final original = _recording('recording-1');
    final expiresAt = DateTime.utc(2026, 10, 1);
    final updated = _recording('recording-1', expiresAt: expiresAt);
    final repository = _FakeRecordingRepository(
      expiryResult: Future.value(updated),
    )..pages[1] = Future.value(_page(1, [original]));
    final viewModel = RecordingListViewModel(repository);
    await viewModel.load();

    await viewModel.setExpiry(original, expiresAt);

    expect(viewModel.items.single.expiresAt, expiresAt);
  });

  test('setExpiry invalidates a stale refresh response', () async {
    final original = _recording('recording-1');
    final expiresAt = DateTime.utc(2026, 10, 1);
    final refresh = Completer<RecordingPage>();
    final repository = _FakeRecordingRepository(
      expiryResult: Future.value(
        _recording('recording-1', expiresAt: expiresAt),
      ),
    )..pages[1] = Future.value(_page(1, [original]));
    final viewModel = RecordingListViewModel(repository);
    await viewModel.load();
    repository.pages[1] = refresh.future;

    final refreshing = viewModel.refresh();
    await viewModel.setExpiry(original, expiresAt);
    refresh.complete(_page(1, [original]));
    await refreshing;

    expect(viewModel.items.single.expiresAt, expiresAt);
  });

  test('refresh waits for an in-flight expiry update', () async {
    final original = _recording('recording-1');
    final expiresAt = DateTime.utc(2026, 10, 1);
    final update = Completer<Recording>();
    final repository = _FakeRecordingRepository(expiryResult: update.future)
      ..pages[1] = Future.value(_page(1, [original]));
    final viewModel = RecordingListViewModel(repository);
    await viewModel.load();

    final updating = viewModel.setExpiry(original, expiresAt);
    final refreshing = viewModel.refresh();
    repository.pages[1] = Future.value(
      _page(1, [_recording('recording-1', expiresAt: expiresAt)]),
    );
    update.complete(_recording('recording-1', expiresAt: expiresAt));
    await updating;
    await refreshing;

    expect(viewModel.items.single.expiresAt, expiresAt);
    expect(repository.listCalls, 2);
  });

  test('setExpiry exposes in-progress and failed mutation state', () async {
    final original = _recording('recording-1');
    final pending = Completer<Recording>();
    final repository = _FakeRecordingRepository(expiryResult: pending.future)
      ..pages[1] = Future.value(_page(1, [original]));
    final viewModel = RecordingListViewModel(repository);
    await viewModel.load();

    final update = viewModel.setExpiry(original, DateTime.utc(2026, 10, 1));

    expect(viewModel.updatingExpiry, isTrue);
    final failure = StateError('update failed');
    pending.completeError(failure);
    await expectLater(update, throwsA(same(failure)));
    expect(viewModel.updatingExpiry, isFalse);
    expect(viewModel.expiryError, same(failure));
    expect(viewModel.items.single.expiresAt, isNull);
  });
}

class _FakeRecordingRepository extends RecordingRepository {
  _FakeRecordingRepository({this.expiryResult}) : super(ApiClient());

  final Map<int, Future<RecordingPage>> pages = {};
  Future<Recording>? expiryResult;
  int listCalls = 0;

  @override
  Future<RecordingPage> listPage({int page = 1, int pageSize = 25}) {
    listCalls++;
    return pages[page]!;
  }

  @override
  Future<Recording> setExpiry(String id, DateTime? expiresAt) => expiryResult!;
}

RecordingPage _page(
  int page,
  List<Recording> items, {
  int? totalItems,
  int totalPages = 1,
}) => RecordingPage(
  items: items,
  page: page,
  pageSize: 25,
  totalItems: totalItems ?? items.length,
  totalPages: totalPages,
);

Recording _recording(String id, {DateTime? expiresAt}) => Recording(
  id: id,
  cameraId: 'front-door',
  startTime: DateTime.utc(2026, 9, 28),
  container: 'mp4',
  playbackUrl: '/api/v1/recordings/$id/media',
  expiresAt: expiresAt,
);
