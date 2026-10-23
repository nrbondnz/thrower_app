import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/history/game_record.dart';
import 'package:thrower_app/history/post_status.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_type.dart';
import 'package:thrower_app/ui/history_screen.dart';

import '../history/memory_game_history.dart';
import '../history/post_status_test.dart' show kept, now, played;
import '../leaderboard/score_post_test.dart' show FakeLeaderboard;

/// Posting-from-history story (Nigel, 2026-10-23): each result says Can be
/// posted, Posted or Cannot be posted; one that can be posted can be posted
/// from its page.
void main() {
  late FakeLeaderboard board;
  late MemoryGameHistory history;

  setUp(() => board = FakeLeaderboard());

  Future<void> pumpList(WidgetTester tester, List<GameRecord> games, {bool iPhone = true}) async {
    history = MemoryGameHistory(games);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameHistoryProvider.overrideWithValue(history),
        clockProvider.overrideWithValue(() => now),
        if (iPhone) leaderboardServiceProvider.overrideWithValue(board),
      ],
      child: const MaterialApp(home: HistoryScreen()),
    ));
    await tester.pumpAndSettle();
  }

  String statusOf(WidgetTester tester, GameRecord g) => tester
      .widget<Text>(find.descendant(of: find.byKey(Key('historyStatus-${g.id}')), matching: find.byType(Text)))
      .data!;

  final ranked = kept(played(GameType.ranked));
  final normal = kept(played(GameType.scoring), at: now.subtract(const Duration(hours: 2)));
  final changed = kept(
    played(GameType.scoring, change: (m) => m.setScore(0, 0, 0, 5)),
    at: now.subtract(const Duration(hours: 3)),
  );

  testWidgets('each result says Can be posted, Posted or Cannot be posted', (tester) async {
    final posted = kept(played(GameType.ranked), at: now.subtract(const Duration(hours: 4))).markedPosted();
    await pumpList(tester, [ranked, changed, posted]);
    expect(statusOf(tester, ranked), 'Can be posted');
    expect(statusOf(tester, changed), 'Cannot be posted');
    expect(statusOf(tester, posted), 'Posted');
  });

  testWidgets("a session's page says why it can't be posted", (tester) async {
    await pumpList(tester, [changed]);
    await tester.tap(find.byKey(Key('historyGame-${changed.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Why: ${NotPostable.changedByHand}.'), findsOneWidget);
    expect(find.byKey(const Key('historyPostScore')), findsNothing);
  });

  testWidgets('a Ranked session posted from History: it goes on the leaderboard and is kept as Posted',
      (tester) async {
    await pumpList(tester, [ranked]);
    await tester.tap(find.byKey(Key('historyGame-${ranked.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('historyPostScore')));
    await tester.pumpAndSettle();
    expect(board.posted.single.$2, 60);
    expect(history.games.single.posted, isTrue);
    expect(find.text('Posted to the leaderboard: 60.'), findsOneWidget);
    expect(find.byKey(const Key('historyPostScore')), findsNothing);
  });

  testWidgets('a normal session waits for "I threw from 3 m"', (tester) async {
    await pumpList(tester, [normal]);
    await tester.tap(find.byKey(Key('historyGame-${normal.id}')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('historyPostScore'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('postAt3m')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('historyPostScore')));
    await tester.pumpAndSettle();
    expect(board.posted.single.$2, 60);
  });

  testWidgets('not signed in to Game Center: not posted, it says so', (tester) async {
    board.signedIn = false;
    await pumpList(tester, [ranked]);
    await tester.tap(find.byKey(Key('historyGame-${ranked.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('historyPostScore')));
    await tester.pumpAndSettle();
    expect(board.posted, isEmpty);
    expect(history.games.single.posted, isFalse);
    expect(find.byKey(const Key('historyPostMessage')), findsOneWidget);
  });

  testWidgets('on Android: Can be posted, but no Post score', (tester) async {
    await pumpList(tester, [ranked], iPhone: false);
    await tester.tap(find.byKey(Key('historyGame-${ranked.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('historyPostScore')), findsNothing);
    expect(find.text('Posting is on the iPhone for now.'), findsOneWidget);
  });
}
