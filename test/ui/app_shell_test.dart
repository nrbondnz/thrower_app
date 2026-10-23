import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/history/game_record.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_type.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/settings/appearance_store.dart';
import 'package:thrower_app/ui/app_shell.dart';
import 'package:thrower_app/ui/home_screen.dart';
import 'package:thrower_app/ui/play_setup_screen.dart';
import 'package:thrower_app/ui/throw_screen.dart';

import '../history/memory_game_history.dart';
import '../history/throw_stats_test.dart' show session, totalsOnly;
import '../leaderboard/score_post_test.dart' show FakeLeaderboard;
import '../settings/appearance_test.dart' show MemoryAppearanceStore;

/// App design story (2026-10-23): the bottom bar, Home, Throw and Setup.
void main() {
  Future<ProviderContainer> pumpShell(WidgetTester tester,
      {List<GameRecord> games = const [], MemoryGameHistory? history, List overrides = const []}) async {
    final c = ProviderContainer(overrides: [
      gameHistoryProvider.overrideWithValue(history ?? MemoryGameHistory(games)),
      appearanceStoreProvider.overrideWithValue(MemoryAppearanceStore()),
      ...overrides.cast(),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: AppShell())));
    await tester.pumpAndSettle();
    return c;
  }

  group('the bottom bar', () {
    testWidgets('Home, Throw, History and Setup', (tester) async {
      await pumpShell(tester);
      for (final label in ['Home', 'Throw', 'History', 'Setup']) {
        expect(find.descendant(of: find.byKey(const Key('appTabs')), matching: find.text(label)), findsOneWidget);
      }
    });

    testWidgets('Throw shows a card for each way to throw', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('Throw'));
      await tester.pumpAndSettle();
      expect(find.byType(ThrowScreen), findsOneWidget);
      expect(find.byKey(const Key('throwRounds')), findsOneWidget);
      expect(find.byKey(const Key('throwQuickDraw')), findsOneWidget);
    });

    testWidgets('Throw: no Leaderboard where scores can\'t be posted (Android)', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('Throw'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('throwLeaderboard')), findsNothing);
    });

    testWidgets('Throw: Leaderboard on the iPhone opens Game Center\'s', (tester) async {
      final board = FakeLeaderboard();
      await pumpShell(tester, overrides: [leaderboardServiceProvider.overrideWithValue(board)]);
      await tester.tap(find.text('Throw'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('throwLeaderboard')));
      await tester.pumpAndSettle();
      expect(board.shown, isNotEmpty);
    });
  });

  group('Home', () {
    testWidgets('the hero: THROWER and what the app does', (tester) async {
      await pumpShell(tester);
      expect(find.text('THROWER'), findsOneWidget);
      expect(find.text(HomeScreen.tagline), findsOneWidget);
    });

    testWidgets('before the first session: "Your sessions will show here."', (tester) async {
      await pumpShell(tester);
      expect(find.text('Your sessions will show here.'), findsOneWidget);
    });

    testWidgets('the last session: points, per knife and 5s', (tester) async {
      await pumpShell(tester, games: [
        session([
          [5, 4, 3],
          [5, 2, 0],
        ]),
      ]);
      final card = find.byKey(const Key('homeLastSession'));
      expect(find.descendant(of: card, matching: find.text('19')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('3.2')), findsOneWidget); // 19 / 6
      expect(find.descendant(of: card, matching: find.text('2')), findsOneWidget); // two 5s
    });

    testWidgets('a session kept before each knife was: points only', (tester) async {
      await pumpShell(tester, games: [
        totalsOnly(session([
          [5, 4, 3]
        ])),
      ]);
      expect(find.text('Per knife'), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('homeLastSession')), matching: find.text('12')), findsOneWidget);
    });

    testWidgets('it names the kind of session', (tester) async {
      await pumpShell(tester, games: [
        session(List.filled(5, [4, 4, 4]), type: GameType.ranked)
      ]);
      expect(find.textContaining(GameType.ranked.label), findsOneWidget);
    });

    testWidgets('tapping the last session shows History', (tester) async {
      await pumpShell(tester, games: [
        session([
          [1, 1, 1]
        ])
      ]);
      await tester.tap(find.byKey(const Key('homeLastSession')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsNothing);
    });

    // Traceability (2026-10-23).
    testWidgets("two throwers: each thrower's points, by name, on the rounds both played", (tester) async {
      await pumpShell(tester, games: [
        GameRecord(
          id: '1',
          finishedAt: DateTime(2026, 10, 23, 12),
          mode: PlayMode.sharedTarget,
          rounds: 3,
          players: [
            [10, 12],
            [9],
          ],
          names: ['Mark', null],
        ),
      ]);
      final card = find.byKey(const Key('homeLastSession'));
      expect(find.descendant(of: card, matching: find.text('Mark')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('10')), findsOneWidget, reason: "Mark's first round only");
      expect(find.descendant(of: card, matching: find.text('Player 2')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('9')), findsOneWidget);
    });

    testWidgets('a Live test session is passed over for the one before it', (tester) async {
      final older = session([
        [1, 1, 1]
      ]);
      final live = GameRecord(
        id: '2',
        finishedAt: older.finishedAt.add(const Duration(hours: 1)),
        mode: PlayMode.solo,
        rounds: 1,
        players: [
          [15]
        ],
        recording: 'Target 1',
      );
      await pumpShell(tester, games: [live, older]);
      final card = find.byKey(const Key('homeLastSession'));
      expect(find.descendant(of: card, matching: find.text('3')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('15')), findsNothing);
    });

    testWidgets('a session kept since: Home and History show it after a tab change', (tester) async {
      final history = MemoryGameHistory();
      await pumpShell(tester, history: history);
      expect(find.text('Your sessions will show here.'), findsOneWidget);
      await history.add(session([
        [5, 5, 5]
      ]));
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('historyStats')), findsOneWidget);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('homeLastSession')), matching: find.text('15')), findsOneWidget);
    });

    testWidgets('Start throwing opens the setup', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.byKey(const Key('homeStart')));
      await tester.pumpAndSettle();
      expect(find.byType(PlaySetupScreen), findsOneWidget);
    });
  });

  group('Setup', () {
    testWidgets('the tools are there, not on Home', (tester) async {
      await pumpShell(tester);
      expect(find.text('Calibrate target'), findsNothing);
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('setupCalibrate')), findsOneWidget);
      expect(find.byKey(const Key('setupLiveTest')), findsOneWidget);
      expect(find.byKey(const Key('setupTestTarget')), findsOneWidget);
    });

    testWidgets('Appearance: choosing Dark makes the app dark, and keeps it', (tester) async {
      final store = MemoryAppearanceStore();
      final c = ProviderContainer(overrides: [
        gameHistoryProvider.overrideWithValue(MemoryGameHistory()),
        appearanceStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(c.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: switch (ref.watch(appearanceProvider)) {
              Appearance.dark => ThemeMode.dark,
              _ => ThemeMode.light,
            },
            home: const AppShell(),
          ),
        ),
      ));
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.byKey(const Key('setupAppearance')))).brightness, Brightness.dark);
      expect(store.kept, Appearance.dark);
    });
  });
}
