import 'dart:async';

import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/core/api/api_endpoints.dart';
import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emits cameras before runtime status requests complete', () async {
    final status = Completer<Object?>();
    final repository = CameraRepository(
      _FakeApiClient(
        cameras: [_cameraJson('front-door')],
        statuses: {'front-door': status.future},
      ),
    );
    final cameras = await repository.list();
    final iterator = StreamIterator(repository.runtimeStateUpdates(cameras));

    expect(cameras.single.runtimeState, 'offline');
    status.complete({'state': 'online'});
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.single.runtimeState, 'online');
    expect(await iterator.moveNext(), isFalse);
  });

  test(
    'distinguishes an unavailable status request from an offline camera',
    () async {
      final repository = CameraRepository(
        _FakeApiClient(
          cameras: [_cameraJson('front-door')],
          statuses: {
            'front-door': Future<Object?>.delayed(
              Duration.zero,
              () => throw StateError('gateway'),
            ),
          },
        ),
      );

      final cameras = await repository.list();
      final snapshots = await repository.runtimeStateUpdates(cameras).toList();

      expect(snapshots.last.single.runtimeState, 'unavailable');
    },
  );

  test('limits runtime status requests to four at a time', () async {
    final statuses = {
      for (var index = 1; index <= 5; index++)
        'camera-$index': Completer<Object?>(),
    };
    final api = _FakeApiClient(
      cameras: [
        for (var index = 1; index <= 5; index++) _cameraJson('camera-$index'),
      ],
      statuses: statuses.map((id, completer) => MapEntry(id, completer.future)),
    );
    final repository = CameraRepository(api);
    final cameras = await repository.list();
    final iterator = StreamIterator(repository.runtimeStateUpdates(cameras));

    final firstBatch = iterator.moveNext();
    await Future<void>.delayed(Duration.zero);
    expect(api.statusCalls, hasLength(4));
    for (final id in api.statusCalls) {
      statuses[id]!.complete({'state': 'online'});
    }
    expect(await firstBatch, isTrue);

    final secondBatch = iterator.moveNext();
    await Future<void>.delayed(Duration.zero);
    expect(api.statusCalls, hasLength(5));
    statuses['camera-5']!.complete({'state': 'online'});
    expect(await secondBatch, isTrue);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({required this.cameras, required this.statuses});

  final List<Object?> cameras;
  final Map<String, Future<Object?>> statuses;
  final List<String> statusCalls = [];

  @override
  Future<Object?> getJson(String path) {
    if (path == ApiEndpoints.cameras) return Future.value(cameras);
    final id = path.split('/')[4];
    statusCalls.add(id);
    return statuses[id]!;
  }
}

Map<String, Object?> _cameraJson(String id) => {
  'id': id,
  'name': 'Front Door',
  'enabled': true,
  'connection': {'host': '192.168.1.10', 'port': 554, 'mainStream': '/main'},
  'recording': {
    'enabled': true,
    'mode': 'continuous',
    'preEventSeconds': 5,
    'postEventSeconds': 15,
    'retentionDays': null,
  },
  'motion': {'enabled': false, 'stream': 'main', 'fps': 5, 'sensitivity': 0.65},
};
