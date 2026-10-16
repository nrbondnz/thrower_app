import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/main.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/debug_target_screen.dart';
import 'package:thrower_app/ui/history_screen.dart';

import 'history/memory_game_history.dart';

void main() {
  testWidgets('home screen opens the scoring test target', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ThrowerApp()));
    expect(find.text('Thrower App'), findsOneWidget);

    await tester.tap(find.text('Scoring test target'));
    await tester.pumpAndSettle();
    expect(find.byType(DebugTargetScreen), findsOneWidget);
  });

  testWidgets('home screen opens the History', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [gameHistoryProvider.overrideWithValue(MemoryGameHistory())],
      child: const ThrowerApp(),
    ));
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
  });
}
