import 'dart:async';

import 'package:aegivue/shared/widgets/app_header_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disables refresh while the current refresh is pending', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppHeaderWidget(
            title: 'Recordings',
            onRefresh: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    await tester.tap(find.byTooltip('Refresh'), warnIfMissed: false);

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
