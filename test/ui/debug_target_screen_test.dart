import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/ui/debug_target_screen.dart';
import 'package:thrower_app/ui/target_painter.dart';

void main() {
  Future<Size> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: DebugTargetScreen())));
    return tester.getSize(find.byKey(const Key('debugTarget')));
  }

  /// Taps the target at normalised point ([x], [y]).
  Future<void> tapAt(WidgetTester tester, Size size, double x, double y) async {
    final topLeft = tester.getTopLeft(find.byKey(const Key('debugTarget')));
    final scale = TargetPainter.scaleFor(size);
    await tester.tapAt(topLeft + size.center(Offset.zero) + Offset(x, y) * scale);
    await tester.pump();
  }

  String scoreText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('scoreText'))).data!;

  testWidgets('prompts for a tap before any hit', (tester) async {
    await pumpScreen(tester);
    expect(scoreText(tester), 'Tap the target');
  });

  testWidgets('tapping the centre scores 5', (tester) async {
    final size = await pumpScreen(tester);
    await tapAt(tester, size, 0, 0);
    expect(scoreText(tester), 'Score: 5');
  });

  testWidgets('tapping outside the rings scores 0', (tester) async {
    final size = await pumpScreen(tester);
    await tapAt(tester, size, 0, 1.08);
    expect(scoreText(tester), 'Score: 0');
  });

  testWidgets('switching to the lower rule rescores a hit touching a line', (tester) async {
    final size = await pumpScreen(tester);
    await tapAt(tester, size, 0.41, 0);
    expect(scoreText(tester), 'Score: 4');

    await tester.tap(find.text('Line = lower'));
    await tester.pump();
    expect(scoreText(tester), 'Score: 3');
  });
}
