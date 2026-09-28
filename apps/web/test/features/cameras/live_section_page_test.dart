@TestOn('browser')
library;

import 'package:aegivue/core/api/api_client.dart';
import 'package:aegivue/features/cameras/data/camera_repository.dart';
import 'package:aegivue/features/cameras/domain/camera.dart';
import 'package:aegivue/features/cameras/presentation/live_section_page.dart';
import 'package:aegivue/features/cameras/presentation/view_models/camera_list_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('keeps loaded content and offers retry after refresh failure', (
    tester,
  ) async {
    final repository = _FakeCameraRepository(Future.value(const []));
    final viewModel = CameraListViewModel(repository);
    await viewModel.load();
    repository.result = Future.error(StateError('offline'));
    await viewModel.refresh();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: viewModel,
        child: const MaterialApp(home: Scaffold(body: LiveSectionPage())),
      ),
    );

    expect(find.text('Unable to refresh camera data'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
    expect(find.text('No cameras registered'), findsOneWidget);
  });
}

class _FakeCameraRepository extends CameraRepository {
  _FakeCameraRepository(this.result) : super(ApiClient());

  Future<List<Camera>> result;

  @override
  Future<List<Camera>> list() => result;
}
