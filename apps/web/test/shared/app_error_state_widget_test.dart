import 'package:aegivue/shared/widgets/app_error_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('identifies Aegivue when the initial load fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppErrorStateWidget(onRetry: () async {})),
      ),
    );

    expect(find.text('Unable to load Aegivue data'), findsOneWidget);
  });
}
