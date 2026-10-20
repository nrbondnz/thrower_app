import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/history/game_history.dart';
import 'package:thrower_app/history/game_record.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_type.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/ui/history_screen.dart';

import '../history/memory_game_history.dart';

/// Game-history story, Task 3: Home → History.
GameRecord game(DateTime at, PlayMode mode, List<List<int>> players,
        {String? recording, List<String?> names = const []}) =>
    GameRecord(
      id: '${at.microsecondsSinceEpoch}',
      finishedAt: at,
      mode: mode,
      rounds: players.first.length,
      players: players,
      names: names,
      recording: recording,
    );

extension on GameRecord {
  /// The same game, planned as [rounds] rounds (finished early if more
  /// than were played).
  GameRecord withRounds(int rounds) =>
      GameRecord(id: id, finishedAt: finishedAt, mode: mode, rounds: rounds, players: players, recording: recording);
}

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
      // Finish game (2026-10-17): fewer rounds than planned; two players
      // judged on equal rounds.
      (
        game(DateTime(2026), PlayMode.solo, [
          [15, 12]
        ]).withRounds(9),
        '1 player · 2 of 9 rounds · Total 27'
      ),
      (
        game(DateTime(2026), PlayMode.sharedTarget, [
          [9, 15],
          [3],
        ]).withRounds(9),
        '2 players, 1 target · 2 of 9 rounds · Player 1 wins 9–3'
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

  testWidgets("a game finished early marks the round that didn't count", (tester) async {
    history = MemoryGameHistory([
      game(DateTime(2026, 10, 17, 10, 0), PlayMode.sharedTarget, [
        [9, 15],
        [3],
      ]).withRounds(9),
    ]);
    await pumpHistory(tester);
    await tester.tap(find.text('17 Oct, 10:00'));
    await tester.pumpAndSettle();
    expect(find.text('Player 1: 9'), findsOneWidget);
    expect(find.text('Round 2: 15 (not counted)'), findsOneWidget);
    expect(find.text('Player 1 wins 9–3'), findsOneWidget);
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

  // Named-players story (2026-10-19).
  group('names', () {
    final at = DateTime(2026, 10, 19, 20, 0);

    test('the result names the winner; games without names say Player N', () {
      final named = game(at, PlayMode.sharedTarget, [[10], [12]], names: ['Jo', 'Sam']);
      expect(resultText(named), 'Sam wins 10–12');
      expect(resultText(game(at, PlayMode.sharedTarget, [[10], [12]])), 'Player 2 wins 10–12');
    });

    test('one named player: the name and total', () {
      expect(resultText(game(at, PlayMode.solo, [[15, 12]], names: ['Jo'])), 'Jo 27');
      expect(resultText(game(at, PlayMode.solo, [[15, 12]])), 'Total 27');
    });

    testWidgets("a game's page heads each player's rounds with their name", (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: GameRecordScreen(game: game(at, PlayMode.sharedTarget, [[10], [12]], names: ['Jo', null])),
        ),
      ));
      expect(tester.widget<Text>(find.byKey(const Key('historyPlayer-0'))).data, 'Jo: 10');
      expect(tester.widget<Text>(find.byKey(const Key('historyPlayer-1'))).data, 'Player 2: 12');
    });
  });

  // More-game-types story (2026-10-20).
  group('game types', () {
    GameRecord typed(GameType type, PlayMode mode, List<List<int>> players, {int? rounds}) => GameRecord(
          id: '9',
          finishedAt: DateTime(2026, 10, 20, 15),
          mode: mode,
          rounds: rounds ?? type.defaultRounds,
          players: players,
          type: type,
        );

    test('Precision leads with the game, and two players take turns', () {
      final g = typed(GameType.precision, PlayMode.sharedTarget, [List.filled(7, 9), List.filled(7, 8)]);
      expect(howText(g), 'Precision · 2 players, taking turns · 7 rounds');
    });

    test('Three targets for one player', () {
      final g = typed(GameType.threeTargets, PlayMode.solo, [List.filled(3, 9)], rounds: 3);
      expect(howText(g), 'Three targets · 1 player · 3 rounds');
    });

    test('a Scoring game reads as before', () {
      final g = typed(GameType.scoring, PlayMode.sharedTarget, [List.filled(3, 9), List.filled(3, 9)], rounds: 3);
      expect(howText(g), '2 players, 1 target · 3 rounds');
    });

    test('Precision rounds show their distance: "Round 2 (5 m)"', () {
      final g = typed(GameType.precision, PlayMode.solo, [List.filled(7, 9)]);
      expect([for (var r = 0; r < 7; r++) historyRoundLabel(g, r)], [
        'Round 1 (3 m)', 'Round 2 (5 m)', 'Round 3 (7 m)', 'Round 4 (3 m)', 'Round 5 (4 m)', 'Round 6 (5 m)',
        'Round 7 (7 m)',
      ]);
    });

    test('other games have no distance on their rounds', () {
      final g = typed(GameType.threeTargets, PlayMode.solo, [List.filled(3, 9)], rounds: 3);
      expect(historyRoundLabel(g, 0), 'Round 1');
    });
  });
}
