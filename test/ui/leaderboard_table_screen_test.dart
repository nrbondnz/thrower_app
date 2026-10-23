import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/leaderboard/game_center_leaderboard_service.dart';
import 'package:thrower_app/leaderboard/leaderboard_service.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/leaderboard_table_screen.dart';

import '../leaderboard/score_post_test.dart' show FakeLeaderboard;

/// Backlog #22 (Nigel, 2026-10-22; weekly since 2026-10-23): the
/// leaderboard's tables, this week and last week.
void main() {
  late FakeLeaderboard board;

  setUp(() => board = FakeLeaderboard());

  Future<void> pumpTables(WidgetTester tester, {bool iPhone = true}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [if (iPhone) leaderboardServiceProvider.overrideWithValue(board)],
      child: const MaterialApp(home: LeaderboardTableScreen(board: Leaderboard.ranked3m)),
    ));
    await tester.pumpAndSettle();
  }

  LeaderboardTable table(List<(int, String, int)> rows, {int? myRank}) => LeaderboardTable(
    entries: [for (final (r, n, s) in rows) LeaderboardEntry(rank: r, name: n, score: s, isMe: r == myRank)],
    me: myRank == null ? null : LeaderboardEntry(rank: myRank, name: 'Nigel', score: 40, isMe: true),
  );

  group('the tables', () {
    testWidgets("this week's table: place, nickname and score", (tester) async {
      board.tables[LeaderboardWeek.thisWeek] = table([(1, 'Mark', 66), (2, 'Captain', 58)]);
      await pumpTables(tester);
      expect(find.text('Mark'), findsOneWidget);
      expect(find.text('66'), findsOneWidget);
      expect(find.byKey(const Key('entry-2')), findsOneWidget);
    });

    testWidgets('the player\'s own row is marked "(you)"', (tester) async {
      board.tables[LeaderboardWeek.thisWeek] = LeaderboardTable(
        entries: const [
          LeaderboardEntry(rank: 1, name: 'Mark', score: 66),
          LeaderboardEntry(rank: 2, name: 'Nigel', score: 60, isMe: true),
        ],
        me: const LeaderboardEntry(rank: 2, name: 'Nigel', score: 60, isMe: true),
      );
      await pumpTables(tester);
      expect(find.text('Nigel (you)'), findsOneWidget);
      expect(find.byKey(const Key('entryMe')), findsOneWidget);
    });

    testWidgets('further down than the top 25: their row under the table', (tester) async {
      board.tables[LeaderboardWeek.thisWeek] = table([(1, 'Mark', 66)], myRank: 40);
      await pumpTables(tester);
      expect(find.text('Nigel (you)'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets("Last week's tab loads last week", (tester) async {
      board.tables[LeaderboardWeek.lastWeek] = table([(1, 'Captain', 70)]);
      await pumpTables(tester);
      await tester.tap(find.byKey(const Key('week-lastWeek')));
      await tester.pumpAndSettle();
      expect(find.text('Captain'), findsOneWidget);
      expect(board.tablesAsked.map((a) => a.$2), contains(LeaderboardWeek.lastWeek));
    });
  });

  group('when there is no table', () {
    testWidgets('no scores yet this week', (tester) async {
      await pumpTables(tester);
      expect(find.byKey(const Key('tableEmpty')), findsOneWidget);
    });

    testWidgets('no results for last week yet (a new leaderboard)', (tester) async {
      await pumpTables(tester);
      await tester.tap(find.byKey(const Key('week-lastWeek')));
      await tester.pumpAndSettle();
      expect(find.text('No results for last week yet.'), findsOneWidget);
    });

    testWidgets('not signed in to Game Center: says so, Try again', (tester) async {
      board.signedIn = false;
      await pumpTables(tester);
      expect(find.byKey(const Key('tableSignedOut')), findsOneWidget);
      board.signedIn = true;
      board.tables[LeaderboardWeek.thisWeek] = table([(1, 'Mark', 66)]);
      await tester.tap(find.byKey(const Key('tableTryAgain')).first);
      await tester.pumpAndSettle();
      expect(find.text('Mark'), findsOneWidget);
    });

    testWidgets('no signal: says so, Try again', (tester) async {
      board.tableFails = true;
      await pumpTables(tester);
      expect(find.byKey(const Key('tableFailed')), findsOneWidget);
    });

    testWidgets('on Android: leaderboards are on the iPhone for now', (tester) async {
      await pumpTables(tester, iPhone: false);
      expect(find.byKey(const Key('tableNotHere')), findsOneWidget);
      expect(find.byKey(const Key('openInGameCenter')), findsNothing);
    });
  });

  testWidgets("Open in Game Center shows Apple's screen", (tester) async {
    await pumpTables(tester);
    await tester.tap(find.byKey(const Key('openInGameCenter')));
    await tester.pumpAndSettle();
    expect(board.shown, [Leaderboard.ranked3m]);
  });

  // The iPhone code's reply (GameCenterTables in ios/Runner/AppDelegate.swift), through
  // the channel.
  group('Game Center: the iPhone code', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;
    Object? Function(MethodCall)? reply;

    setUp(() {
      calls = [];
      messenger.setMockMethodCallHandler(GameCenterLeaderboardService.channel, (call) async {
        calls.add(call);
        return reply?.call(call);
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(GameCenterLeaderboardService.channel, null));

    test('asks for the leaderboard, the week and 25 places', () async {
      reply = (_) => {'entries': <Object?>[]};
      await GameCenterLeaderboardService().loadTable(Leaderboard.ranked3m, LeaderboardWeek.lastWeek);
      expect(calls.single.method, 'loadTable');
      expect(calls.single.arguments, {'leaderboardID': 'ranked.3m.5x3', 'previous': true, 'count': 25});
    });

    test('reads the rows, the player and the week\'s start', () async {
      reply = (_) => {
        'entries': [
          {'rank': 1, 'name': 'Mark', 'score': 66, 'me': false},
          {'rank': 2, 'name': 'Nigel', 'score': 60, 'me': true},
        ],
        'me': {'rank': 2, 'name': 'Nigel', 'score': 60, 'me': true},
        'start': DateTime.utc(2026, 10, 23).millisecondsSinceEpoch,
      };
      final t = await GameCenterLeaderboardService().loadTable(Leaderboard.ranked3m, LeaderboardWeek.thisWeek);
      expect([for (final e in t.entries) (e.rank, e.name, e.score, e.isMe)], [(1, 'Mark', 66, false), (2, 'Nigel', 60, true)]);
      expect((t.me?.rank, t.meBelow, t.weekStart), (2, false, DateTime.utc(2026, 10, 23)));
    });

    test('no score this week: no "me"', () async {
      reply = (_) => {'entries': <Object?>[], 'me': null};
      final t = await GameCenterLeaderboardService().loadTable(Leaderboard.ranked3m, LeaderboardWeek.thisWeek);
      expect((t.isEmpty, t.me), (true, null));
    });

    test('signed out of Game Center: LeaderboardSignedOut', () async {
      reply = (_) => throw PlatformException(code: 'signedOut');
      expect(
        GameCenterLeaderboardService().loadTable(Leaderboard.ranked3m, LeaderboardWeek.thisWeek),
        throwsA(isA<LeaderboardSignedOut>()),
      );
    });

    test('any other failure is passed on', () async {
      reply = (_) => throw PlatformException(code: 'failed');
      expect(
        GameCenterLeaderboardService().loadTable(Leaderboard.ranked3m, LeaderboardWeek.thisWeek),
        throwsA(isA<PlatformException>()),
      );
    });
  });
}
