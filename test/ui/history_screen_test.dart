import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/history/game_history.dart';
import 'package:thrower_app/history/game_record.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/ui/history_screen.dart';

import '../history/memory_game_history.dart';

/// Game-history story, Task 3: Home → History.
GameRecord game(DateTime at, PlayMode mode, List<List<int>> players, {String? recording}) => GameRecord(
      id: '${at.microsecondsSinceEpoch}',
      finishedAt: at,
      mode: mode,
      rounds: players.first.length,
      players: players,
      recording: recording,
    );

final older = game(DateTime(2026, 10, 15, 9, 5), PlayMode.solo, [
  [15, 10, 12]
]);
final newer = game(DateTime(2026, 10, 16, 14, 32), PlayMode.sharedTarget, [
  [12, 15, 10, 9, 15],
  [14, 13, 12, 10, 9],
]);

void main() {
  late MemoryGameHistory history;

  Future<void> pumpHistory(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [gameHistoryProvider.overrideWithValue(history)],
      child: const MaterialApp(home: HistoryScreen()),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() => history = MemoryGameHistory([older, newer]));

  group('the text', () {
    test('when a game finished: day, month and a 24-hour time', () {
      expect(whenText(DateTime(2026, 10, 6, 9, 5)), '6 Oct, 09:05');
    });

    final cases = [
      (older, '1 player · 3 rounds · Total 37'),
      (newer, '2 players, 1 target · 5 rounds · Player 1 wins 61–58'),
      (
        game(DateTime(2026), PlayMode.twoTargets, [
          [5, 5, 5],
          [10, 0, 5],
        ]),
        '2 players, 2 targets · 3 rounds · A draw 15–15'
      ),
      (
        game(DateTime(2026), PlayMode.solo, [
          [5, 5, 5]
        ], recording: 'Target 1'),
        '1 player · 3 rounds · Live test: Target 1 · Total 15'
      ),
    ];
    for (final (g, expected) in cases) {
      test('a list line reads "$expected"', () => expect(summaryText(g), expected));
    }
  });

  testWidgets('lists the games newest first, with how each was played', (tester) async {
    await pumpHistory(tester);
    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect([for (final t in tiles) (t.title as Text).data], ['16 Oct, 14:32', '15 Oct, 09:05']);
  });

  testWidgets('says "No games yet" when there are none, with no Clear history', (tester) async {
    history = MemoryGameHistory();
    await pumpHistory(tester);
    expect(find.byKey(const Key('historyEmpty')), findsOneWidget);
    expect(find.byKey(const Key('historyClear')), findsNothing);
  });

  testWidgets("says it couldn't load the history, and tries again", (tester) async {
    history.failWith = const GameHistoryException('the history was damaged; it was set aside', setAside: true);
    await pumpHistory(tester);
    expect(find.byKey(const Key('historyLoadFailed')), findsOneWidget);
    expect(find.textContaining('set aside'), findsOneWidget);
    history.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets("a game shows every round of each player, the totals and the winner", (tester) async {
    await pumpHistory(tester);
    await tester.tap(find.text('16 Oct, 14:32'));
    await tester.pumpAndSettle();
    expect(find.byType(GameRecordScreen), findsOneWidget);
    expect(find.text('Player 1 wins 61–58'), findsOneWidget);
    expect(find.text('Player 2: 58'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('historyRound-1-4'))).data, 'Round 5: 9');
    expect(find.byKey(const Key('historyRound-0-0')), findsOneWidget);
  });

  testWidgets('deleting a game removes it and goes back to the list', (tester) async {
    await pumpHistory(tester);
    await tester.tap(find.text('16 Oct, 14:32'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('historyDelete')));
    await tester.pumpAndSettle();
    expect(find.byType(GameRecordScreen), findsNothing);
    expect(history.games, [older]);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('Clear history asks first; Cancel keeps every game', (tester) async {
    await pumpHistory(tester);
    await tester.tap(find.byKey(const Key('historyClear')));
    await tester.pumpAndSettle();
    expect(find.text('Clear history?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(history.games, hasLength(2));
  });

  testWidgets('Clear history, confirmed, removes every game', (tester) async {
    await pumpHistory(tester);
    await tester.tap(find.byKey(const Key('historyClear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('historyClearConfirm')));
    await tester.pumpAndSettle();
    expect(history.games, isEmpty);
    expect(find.byKey(const Key('historyEmpty')), findsOneWidget);
  });
}
