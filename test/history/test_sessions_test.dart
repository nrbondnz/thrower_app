import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/history/post_status.dart';
import 'package:thrower_app/history/test_sessions.dart';
import 'package:thrower_app/history/throw_stats.dart';
import 'package:thrower_app/leaderboard/leaderboard_service.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/setup_screen.dart';

import 'memory_game_history.dart';
import 'post_status_test.dart' show kept, now, played;
import 'package:thrower_app/scoring/game_type.dart';

/// Posting-from-history story (Nigel, 2026-10-23): test sessions that can be
/// posted, made fresh each time.
void main() {
  group('makeTestSessions', () {
    final sessions = makeTestSessions(now, random: Random(1));

    test('10 of them, each with its own id', () {
      expect((sessions.length, {for (final s in sessions) s.id}.length), (10, 10));
    });

    test('every one can be posted now, in a test build', () {
      expect({for (final s in sessions) postStatusOf(s, now, testTools: true).state}, {PostState.canPost});
    });

    // Review Agent, 2026-10-23: test sessions must never reach the real
    // leaderboard.
    test('not in a build without the test tools', () {
      expect(postStatusOf(sessions.first, now), const PostStatus(PostState.cannotPost, NotPostable.testSession));
    });

    test('posted to the test leaderboard, never the real one', () {
      expect({for (final s in sessions) leaderboardFor(s)}, {Leaderboard.test3m});
      expect(leaderboardFor(kept(played(GameType.ranked))), Leaderboard.ranked3m);
    });

    test('marked test, 5 rounds of 3 knives scoring 0 to 5', () {
      for (final s in sessions) {
        expect(s.test, isTrue);
        expect(s.knives!.single.map((r) => r.length), List.filled(5, 3));
        expect(s.knives!.single.expand((r) => r).every((k) => k >= 0 && k <= 5), isTrue);
        expect(s.totals.single, s.knives!.single.expand((r) => r).fold(0, (a, b) => a + b));
      }
    });

    test('a mix of Ranked and normal 5 × 3', () {
      expect({for (final s in sessions) s.type}, {GameType.ranked, GameType.scoring});
    });

    test('different each time', () {
      final again = makeTestSessions(now, random: Random(2));
      expect([for (final s in again) s.totals.single], isNot([for (final s in sessions) s.totals.single]));
    });

    test('thrown this leaderboard week, not in the future', () {
      for (final s in sessions) {
        expect(s.finishedAt.isAfter(now), isFalse);
      }
    });

    test('left out of the stats', () {
      expect(ThrowStats.of([...sessions, kept(played(GameType.ranked))]).sessions, 1);
    });
  });

  group('Setup → Test sessions', () {
    late MemoryGameHistory history;

    Future<void> pumpSetup(WidgetTester tester, {required bool tools, bool recordings = true}) async {
      history = MemoryGameHistory([kept(played(GameType.ranked))]);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          gameHistoryProvider.overrideWithValue(history),
          clockProvider.overrideWithValue(() => now),
          testToolsProvider.overrideWithValue(tools),
          liveRecordingsProvider.overrideWith((ref) async => recordings),
        ],
        child: const MaterialApp(home: SetupScreen()),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> tapTile(WidgetTester tester, String key) async {
      await tester.scrollUntilVisible(find.byKey(Key(key)), 100);
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('not in an App Store build', (tester) async {
      await pumpSetup(tester, tools: false);
      expect(find.byKey(const Key('setupAddTestSessions')), findsNothing);
    });

    // Store-release hygiene (backlog #6, 2026-10-23): Live test plays
    // recordings of real people; the scoring test target is a developer's
    // check. Both are test-build tools.
    testWidgets('no Live test or Scoring test target in an App Store build', (tester) async {
      await pumpSetup(tester, tools: false);
      await tester.scrollUntilVisible(find.byKey(const Key('setupCalibrate')), 100);
      expect(find.byKey(const Key('setupLiveTest')), findsNothing);
      expect(find.byKey(const Key('setupTestTarget')), findsNothing);
    });

    testWidgets('both in a test build', (tester) async {
      await pumpSetup(tester, tools: true);
      await tester.scrollUntilVisible(find.byKey(const Key('setupTestTarget')), 100);
      expect(find.byKey(const Key('setupLiveTest')), findsOneWidget);
    });

    // Flavors (2026-10-23): the recordings are in the beta flavor only. A
    // test build made without it (an iPhone build before its schemes) has no
    // Live test to offer.
    testWidgets('a test build without the recordings: no Live test, the test target still there', (tester) async {
      await pumpSetup(tester, tools: true, recordings: false);
      await tester.scrollUntilVisible(find.byKey(const Key('setupTestTarget')), 100);
      expect(find.byKey(const Key('setupLiveTest')), findsNothing);
    });

    testWidgets('Add 10 test sessions adds 10 more each time', (tester) async {
      await pumpSetup(tester, tools: true);
      await tapTile(tester, 'setupAddTestSessions');
      expect(history.games.where((g) => g.test).length, 10);
      await tapTile(tester, 'setupAddTestSessions');
      expect(history.games.where((g) => g.test).length, 20);
    });

    testWidgets('Remove test sessions leaves the real ones', (tester) async {
      await pumpSetup(tester, tools: true);
      await tapTile(tester, 'setupAddTestSessions');
      await tapTile(tester, 'setupRemoveTestSessions');
      expect((history.games.length, history.games.single.test), (1, false));
    });
  });
}
