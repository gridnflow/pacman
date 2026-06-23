// Smoke test for the app shell. The default Flutter counter template that
// shipped here referenced a non-existent `MyApp`; this verifies the real
// [ChompireApp] builds without throwing.

import 'package:flutter_test/flutter_test.dart';

import 'package:chompire/main.dart';

void main() {
  testWidgets('ChompireApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ChompireApp());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
