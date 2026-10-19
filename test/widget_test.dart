import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/main.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/debug_target_screen.dart';
import 'package:thrower_app/ui/history_screen.dart';

import 'history/memory_game_history.dart';
import 'ui/account_screen_test.dart' show FakeAuthService;

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

  // Accounts Task 2 (Nigel, 2026-10-19: "Not super happy about having to login
  // right from the start"): with accounts connected and no one signed in, the
  // app still opens on Home, never on a sign-in screen.
  testWidgets('with accounts, signed out: the app opens on Home, not a sign-in screen', (tester) async {
    // Amplify's Authenticator starts a repeating timer: build it with real
    // timers (runAsync), which the test doesn't flag when it ends.
    await tester.runAsync(() async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(FakeAuthService()),
          gameHistoryProvider.overrideWithValue(MemoryGameHistory()),
        ],
        child: const ThrowerApp(),
      ));
    });
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    expect(find.byKey(const Key('homeAccount')), findsOneWidget);
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
  });
}

