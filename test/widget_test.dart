import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/main.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/debug_target_screen.dart';
import 'package:thrower_app/ui/history_screen.dart';
import 'package:thrower_app/ui/setup_screen.dart';

import 'history/memory_game_history.dart';
import 'ui/account_screen_test.dart' show FakeAuthService;

void main() {
  testWidgets('the app opens on Home: THROWER, and Start throwing', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [gameHistoryProvider.overrideWithValue(MemoryGameHistory())],
      child: const ThrowerApp(),
    ));
    await tester.pump();
    expect(find.text('THROWER'), findsOneWidget);
    expect(find.text('START THROWING'), findsOneWidget);
  });

  testWidgets('Setup opens the scoring test target', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [gameHistoryProvider.overrideWithValue(MemoryGameHistory())],
      child: const ThrowerApp(),
    ));
    await tester.tap(find.text('Setup'));
    await tester.pumpAndSettle();
    expect(find.byType(SetupScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('setupTestTarget')), 100);
    await tester.ensureVisible(find.byKey(const Key('setupTestTarget')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('setupTestTarget')));
    await tester.pumpAndSettle();
    expect(find.byType(DebugTargetScreen), findsOneWidget);
  });

  testWidgets('the History tab', (tester) async {
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
    expect(find.text('START THROWING'), findsOneWidget);
    await tester.runAsync(() => tester.pumpWidget(const SizedBox()));
  });
}
