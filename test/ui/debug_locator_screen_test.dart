import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/ui/debug_locator_screen.dart';

void main() {
  String resultText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('locatorResult'))).data!;

  /// Real async work (isolates, image decoding) needs runAsync in widget tests.
  Future<void> waitForResult(WidgetTester tester) async {
    for (var i = 0; i < 100 && resultText(tester).startsWith('Finding'); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
  }

  testWidgets('finds the rings on each synthetic sample', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: DebugLocatorScreen())));
    for (final sample in locatorSamples.where((s) => s.label.startsWith('Synthetic'))) {
      await tester.ensureVisible(find.text(sample.label));
      await tester.tap(find.text(sample.label));
      await tester.pump();
      expect(resultText(tester), startsWith('Finding'), reason: 'tap on ${sample.label} should start a new search');
      await waitForResult(tester);
      expect(resultText(tester), startsWith('Found'), reason: sample.label);
    }
  });
}
