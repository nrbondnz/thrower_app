import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/ui/score_corrections.dart';

import 'play_screen_test.dart' show GameWith, SharedGameWith;

/// Score corrections story, Task 2: tappable scores and the 0–5 popup.
class FakeHost implements CorrectionHost {
  final calls = <String>[];
  final added = <(int, ThrowSlot, bool)>[];

  @override
  void pauseWatching() => calls.add('pause');

  @override
  void resumeWatching() => calls.add('resume');

  @override
  void addedByHand(int board, ThrowSlot slot, {required bool newRound}) => added.add((board, slot, newRound));
}

void main() {
  late FakeHost host;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, GameNotifier Function() game, {int player = 0, String? label}) async {
    host = FakeHost();
    await tester.pumpWidget(ProviderScope(
      overrides: [gameProvider.overrideWith(game)],
      child: MaterialApp(
        home: Scaffold(body: Center(child: ScoreCorrections(host: host, player: player, board: 0, label: label))),
      ),
    ));
    container = ProviderScope.containerOf(tester.element(find.byType(ScoreCorrections)));
  }

  /// The button inside a slot (the key is on the slot around it).
  OutlinedButton button(WidgetTester tester, String key) =>
      tester.widget<OutlinedButton>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(OutlinedButton)));

  String slot(WidgetTester tester, int player, int i) => (button(tester, 'slot-$player-$i').child as Text).data!;

  Future<void> tapAndPick(WidgetTester tester, Key slot, int score) async {
    await tester.tap(find.byKey(slot));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('pickScore$score')));
    await tester.pumpAndSettle();
  }

  test('the choices are 0 and each ring, lowest first', () {
    expect(scoreChoices([5, 4, 3, 2, 1]), [0, 1, 2, 3, 4, 5]);
  });

  testWidgets("shows the round's throws, then an empty slot for each to come", (tester) async {
    await pump(tester, () => GameWith(2));
    expect([for (var i = 0; i < 3; i++) slot(tester, 0, i)], ['4', '4', '–']);
  });

  testWidgets('a score tapped and changed: the game has it, marked ✎, with watching paused meanwhile', (tester) async {
    await pump(tester, () => GameWith(2));
    await tapAndPick(tester, const Key('slot-0-1'), 1);
    expect(container.read(gameProvider).players.single.rounds.single.throws[1].score, 1);
    expect(slot(tester, 0, 1), '1✎');
    expect(host.calls, ['pause', 'resume']);
  });

  testWidgets('the popup offers 0 to 5, and Cancel changes nothing', (tester) async {
    await pump(tester, () => GameWith(1));
    await tester.tap(find.byKey(const Key('slot-0-0')));
    await tester.pumpAndSettle();
    for (var s = 0; s <= 5; s++) {
      expect(find.byKey(Key('pickScore$s')), findsOneWidget);
    }
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(gameProvider).players.single.total, 4);
    expect(host.calls, ['pause', 'resume']);
  });

  testWidgets('the first empty slot adds a throw: 0 is a miss, marked beside the board', (tester) async {
    await pump(tester, () => GameWith(1));
    await tapAndPick(tester, const Key('slot-0-1'), 0);
    final t = container.read(gameProvider).players.single.rounds.single.throws.last;
    expect((t.result, t.score), (ThrowResult.missed, 0));
    expect(host.added, [(0, (player: 0, round: 0, index: 1), false)]);
  });

  testWidgets('only the first empty slot can be tapped', (tester) async {
    await pump(tester, () => GameWith(1));
    expect(button(tester, 'slot-0-2').onPressed, isNull);
  });

  testWidgets("one target: the other player's empty slots can't add a throw mid-turn", (tester) async {
    await pump(tester, () => SharedGameWith(1), player: 1, label: 'P2');
    expect(button(tester, 'slot-1-0').onPressed, isNull);
  });

  testWidgets('an earlier round: Rounds → the round → change a throw', (tester) async {
    await pump(tester, () => GameWith(4));
    await tester.tap(find.byKey(const Key('rounds-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('round-0-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('roundSlot-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickScore5')));
    await tester.pumpAndSettle();
    expect(find.text('Round 1: 13'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(container.read(gameProvider).players.single.rounds.first.total, 13);
    expect(host.calls, ['pause', 'resume'], reason: 'paused once, for the whole visit');
  });

  testWidgets('no Rounds button before an earlier round exists', (tester) async {
    await pump(tester, () => GameWith(2));
    expect(find.byKey(const Key('rounds-0')), findsNothing);
  });
}
