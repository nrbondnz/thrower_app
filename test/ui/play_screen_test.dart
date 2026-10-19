import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/ui/play_screen.dart';
import 'package:thrower_app/ui/score_corrections.dart';

import 'system_bars_test.dart' show LockedCalibration, pumpWithNavBar;

const p = TargetPoint(0.1, 0.1);

/// A game that starts with [throws] scored throws of 4.
class GameWith extends GameNotifier {
  GameWith(this.throws);

  final int throws;

  @override
  Match build() {
    var g = Match(PlayMode.solo);
    for (var i = 0; i < throws; i++) {
      g = g.stuck(4, p);
    }
    return g;
  }
}

Future<void> pumpPlay(WidgetTester tester, int throws) => pumpWithNavBar(tester, const PlayScreen(), overrides: [
      calibrationProvider.overrideWith(LockedCalibration.new),
      gameProvider.overrideWith(() => GameWith(throws)),
    ]);

/// Two players on one target, after [throws] throws of 4 (Player 1's 3,
/// then Player 2's, …), collecting after each full turn if [collect].
class SharedGameWith extends GameNotifier {
  SharedGameWith(this.throws, {this.collect = true});

  final int throws;
  final bool collect;

  @override
  Match build() {
    var m = Match(PlayMode.sharedTarget);
    for (var i = 0; i < throws; i++) {
      m = m.stuck(4, p);
      if (collect && m.turnComplete) m = m.boardVisited();
    }
    return m;
  }
}

/// Two named players on one target, Player 1's turn done: [names]' second
/// player is up.
class NamedShared extends GameNotifier {
  NamedShared(this.names);

  final List<String?> names;

  @override
  Match build() => Match(PlayMode.sharedTarget, names: names).stuck(4, p).stuck(4, p).stuck(4, p).boardVisited();
}

Future<void> pumpShared(WidgetTester tester, int throws, {bool collect = true}) =>
    pumpWithNavBar(tester, const PlayScreen(), overrides: [
      calibrationProvider.overrideWith(LockedCalibration.new),
      gameProvider.overrideWith(() => SharedGameWith(throws, collect: collect)),
    ]);

String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

/// The camera's loading spinner never stops in tests, so pumpAndSettle would
/// time out: pump long enough for dialog animations instead.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

String gameText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('gameText'))).data!;

void main() {
  testWidgets('Reset game is disabled before the first throw', (tester) async {
    await pumpPlay(tester, 0);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Reset game')).onPressed, isNull);
  });

  testWidgets('Reset game asks first; Cancel keeps the scores', (tester) async {
    await pumpPlay(tester, 2);
    await tester.tap(find.text('Reset game'));
    await settle(tester);
    expect(find.text('Reset this game?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(gameText(tester), contains('Game total: 8'));
  });

  testWidgets('confirming Reset clears the game', (tester) async {
    await pumpPlay(tester, 2);
    await tester.tap(find.text('Reset game'));
    await settle(tester);
    await tester.tap(find.text('Reset'));
    await settle(tester);
    expect(gameText(tester), 'Game total: 0');
  });

  testWidgets('no New game button while the game is on', (tester) async {
    await pumpPlay(tester, 26);
    expect(find.widgetWithText(FilledButton, 'New game'), findsNothing);
  });

  testWidgets('game over shows New game, which starts again without asking', (tester) async {
    await pumpPlay(tester, 27);
    expect(gameText(tester), startsWith('Game over! Final total: 108'));
    await tester.tap(find.widgetWithText(FilledButton, 'New game'));
    await settle(tester);
    expect(find.text('Reset this game?'), findsNothing);
    expect(gameText(tester), 'Game total: 0');
  });

  testWidgets('says when a finished game could not be saved to History', (tester) async {
    await pumpPlay(tester, 0);
    ProviderScope.containerOf(tester.element(find.byType(PlayScreen))).read(historySaveErrorProvider.notifier).set('disk full');
    await tester.pump();
    expect(find.byKey(const Key('historySaveFailed')), findsOneWidget);
  });

  group('two players on one target', () {
    testWidgets("says whose turn it is, in large type, with both players' totals", (tester) async {
      await pumpShared(tester, 4);
      expect(textOf(tester, 'turnText'), "Player 2's turn");
      expect(tester.widget<Text>(find.byKey(const Key('turnText'))).style!.fontSize, greaterThanOrEqualTo(32));
      expect(textOf(tester, 'playerTitle0'), 'Player 1: 12');
      expect(textOf(tester, 'playerTitle1'), 'Player 2: 4');
      expect(textOf(tester, 'playerDetail1'), 'Round 1 of 9: 4 · – · –  (4)');
      expect(find.byKey(const Key('roundText')), findsNothing);
      expect(find.byKey(const Key('turnDetail')), findsNothing);
    });

    testWidgets('after a full turn: collect first, then the next player', (tester) async {
      await pumpShared(tester, 3, collect: false);
      expect(textOf(tester, 'turnText'), 'Collect your knives');
      expect(textOf(tester, 'turnDetail'), "When no one is throwing. Then Player 2's turn.");
    });

    testWidgets('at the end: the winner, every round, and New game', (tester) async {
      await pumpShared(tester, 54);
      expect(textOf(tester, 'turnText'), 'A draw');
      expect(textOf(tester, 'playerDetail0'), 'Rounds: 12, 12, 12, 12, 12, 12, 12, 12, 12');
      expect(textOf(tester, 'matchFooter'), 'Collect your knives when no one is throwing.');
      await tester.tap(find.widgetWithText(FilledButton, 'New game'));
      await settle(tester);
      expect(textOf(tester, 'turnText'), "Player 1's turn");
      expect(textOf(tester, 'playerTitle1'), 'Player 2: 0');
    });
  });

  group('two-player text', () {
    test('a winner', () {
      var m = Match(PlayMode.sharedTarget, rules: const GameSession(maxRounds: 1));
      m = m.stuck(5, p).stuck(5, p).stuck(5, p).boardVisited().stuck(1, p).bounceOut().stuck(2, p);
      expect(turnText(m), 'Player 1 wins');
      expect(playerTitle(m, 0), 'Player 1: 15');
      expect(playerDetail(m, 1), 'Rounds: 3');
    });

    test('a message shows under the players while the game is on', () {
      expect(matchFooter(Match(PlayMode.sharedTarget), message: 'Bounced off: 0.'), 'Bounced off: 0.');
      expect(matchFooter(Match(PlayMode.sharedTarget)), '');
    });
  });

  // Finish game (Nigel, 2026-10-17).
  group('Finish game', () {
    Finder finishButton() => find.byKey(const Key('finishGame'));

    testWidgets("can't be tapped before the first throw", (tester) async {
      await pumpPlay(tester, 0);
      expect(tester.widget<TextButton>(finishButton()).onPressed, isNull);
    });

    testWidgets('asks first; Cancel keeps playing', (tester) async {
      await pumpPlay(tester, 4);
      await tester.tap(finishButton());
      await settle(tester);
      expect(find.text('Finish the game now?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(gameText(tester), isNot(contains('Game over')));
    });

    testWidgets('Finish ends the game after the rounds played, with New game, and the button goes', (tester) async {
      await pumpPlay(tester, 4);
      await tester.tap(finishButton());
      await settle(tester);
      await tester.tap(find.byKey(const Key('finishGameConfirm')));
      await settle(tester);
      expect(gameText(tester), startsWith('Game over after 2 of 9 rounds! Final total: 16'));
      expect(find.text('New game'), findsOneWidget);
      expect(finishButton(), findsNothing);
    });
  });

  group('finished early, two players', () {
    Match sharedFinished() {
      var m = Match(PlayMode.sharedTarget);
      for (final s in [3, 3, 3, 1, 1, 1, 5, 5, 5]) {
        m = m.stuck(s, p);
        if (m.turnComplete) m = m.boardVisited();
      }
      return m.finish();
    }

    test("the winner's total is on equal rounds; an extra round is marked not counted", () {
      final m = sharedFinished();
      expect(turnText(m), 'Player 1 wins');
      expect(playerTitle(m, 0), 'Player 1: 9');
      expect(playerDetail(m, 0), 'Rounds: 9, 15 (not counted)');
      expect(playerDetail(m, 1), 'Rounds: 3');
    });

    test('says it finished early, and on how many rounds it was judged', () {
      expect(matchFooter(sharedFinished()), startsWith('Finished early: judged on 1 of 9 rounds.'));
    });
  });

  // Score corrections story, Task 2.
  testWidgets("Play shows the round's scores as slots to tap, under the totals", (tester) async {
    await pumpPlay(tester, 2);
    expect(find.byType(ScoreCorrections), findsOneWidget);
  });

  testWidgets('two players taking turns: a row of slots each', (tester) async {
    await pumpShared(tester, 4);
    expect(find.byType(ScoreCorrections), findsNWidgets(2));
  });

  test('a score set by hand is marked light blue on the picture; others keep their colour', () {
    const t = ThrowRecord(ThrowResult.stuck, 4, point: p);
    expect(markColour(t, Colors.yellowAccent), Colors.yellowAccent);
    expect(markColour(t.withScore(2), Colors.yellowAccent), Colors.lightBlueAccent);
  });

  // Score corrections story, Task 3.
  test('the phone-moved message says to check the rings and calibrate again', () {
    expect(phoneMovedMessage, contains('The phone may have moved'));
    expect(phoneMovedMessage, contains('calibrate again when no one is throwing'));
  });

  // Named-players story (Nigel, 2026-10-19): names everywhere a player is
  // named, "Player N" without one.
  group('names', () {
    final named = Match(PlayMode.sharedTarget, rules: const GameSession(maxRounds: 1), names: ['Jo', 'Sam']);

    test("whose turn, who's next, the totals", () {
      final turnDone = named.stuck(4, p).stuck(4, p).stuck(4, p);
      expect(turnText(named), "Jo's turn");
      expect(turnDetail(turnDone), "When no one is throwing. Then Sam's turn.");
      expect(playerTitle(turnDone, 0), 'Jo: 12');
    });

    test('the winner', () {
      final m = named.stuck(5, p).stuck(5, p).stuck(5, p).boardVisited().stuck(1, p).bounceOut().stuck(2, p);
      expect(turnText(m), 'Jo wins');
    });

    test('two targets: who to wait for', () {
      final m = Match(PlayMode.twoTargets, names: ['Jo', 'Sam']).stuck(4, p).stuck(4, p).stuck(4, p);
      expect(turnText(m), 'Wait for Sam');
    });

    test("a correction row's label: P1 without a name, a short name, or its first letters", () {
      final m = Match(PlayMode.sharedTarget, names: [null, 'Bartholomew']);
      expect(rowLabel(m, 0), 'P1');
      expect(rowLabel(Match(PlayMode.sharedTarget, names: ['Jo']), 0), 'Jo');
      expect(rowLabel(m, 1), 'Barth…');
    });

    testWidgets('the longest name fits Play on a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpWithNavBar(tester, const PlayScreen(), overrides: [
        calibrationProvider.overrideWith(LockedCalibration.new),
        gameProvider.overrideWith(() => NamedShared(['Bartholomew Smit', 'Maximilian Jones'])),
      ]);
      expect(tester.takeException(), isNull);
      expect(textOf(tester, 'turnText'), "Maximilian Jones's turn");
    });
  });
}
