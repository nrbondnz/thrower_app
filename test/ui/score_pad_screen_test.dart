import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/target_camera.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/game_type.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/ui/play_setup_screen.dart';
import 'package:thrower_app/ui/score_pad_screen.dart';

import '../history/memory_game_history.dart';
import '../settings/player_names_test.dart' show MemoryPlayerNamesStore;

/// More-game-types story, Task 2: choosing Precision or Three targets on
/// Play's setup screen, and scoring them by hand on the score pad.
void main() {
  late ProviderContainer container;
  late MemoryGameHistory history;

  Future<void> pumpSetup(WidgetTester tester, {List<String?> kept = const []}) async {
    history = MemoryGameHistory();
    container = ProviderContainer(overrides: [
      // No camera starts in a test (Scoring's Play would open one).
      cameraProvider.overrideWith((ref) => Completer<TargetCamera>().future),
      playerNamesStoreProvider.overrideWithValue(MemoryPlayerNamesStore(kept)),
      gameHistoryProvider.overrideWithValue(history),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlaySetupScreen()),
    ));
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(f);
    await tester.pump();
  }

  Future<void> start(WidgetTester tester) async {
    await tap(tester, find.byKey(const Key('playStart')));
    await tester.pump(const Duration(milliseconds: 500)); // The page transition.
  }

  Future<void> score(WidgetTester tester, int s, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.byKey(Key('pad$s')));
      await tester.pump();
    }
  }

  String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

  group('the setup screen', () {
    testWidgets('offers Scoring, Precision and Three targets, Scoring first', (tester) async {
      await pumpSetup(tester);
      expect(find.text('Which game?'), findsOneWidget);
      for (final t in GameType.values) {
        expect(find.byKey(Key('playGame-${t.name}')), findsOneWidget);
      }
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('playGame-scoring'))).selected, isTrue);
    });

    testWidgets('Precision: 7 rounds fixed, the distances described, no target choice', (tester) async {
      await pumpSetup(tester);
      await tap(tester, find.byKey(const Key('playGame-precision')));
      await tap(tester, find.text('2 players'));
      expect(find.text('How many targets?'), findsNothing);
      expect(text(tester, 'playRoundsFixed'), '7 rounds');
      expect(text(tester, 'playModeDescription'), contains('3, 5, 7, 3, 4, 5, 7 m'));
      expect(text(tester, 'playModeDescription'), contains('Take turns'));
    });

    testWidgets('Three targets offers 3, 5 or 7 rounds', (tester) async {
      await pumpSetup(tester);
      await tap(tester, find.byKey(const Key('playGame-threeTargets')));
      final rounds = tester.widget<SegmentedButton<int>>(find.byKey(const Key('playRounds')));
      expect([for (final s in rounds.segments) s.value], [3, 5, 7]);
      expect(rounds.selected, {7});
    });

    testWidgets('Start with Three targets, 2 players and 3 rounds opens the score pad', (tester) async {
      await pumpSetup(tester);
      await tap(tester, find.byKey(const Key('playGame-threeTargets')));
      await tap(tester, find.text('2 players'));
      await tap(tester, find.text('3'));
      await start(tester);
      expect(find.byType(ScorePadScreen), findsOneWidget);
      final match = container.read(gameProvider);
      expect((match.type, match.mode, match.maxRounds), (GameType.threeTargets, PlayMode.sharedTarget, 3));
    });

    testWidgets('back to Scoring, the rounds go back to Scoring\'s (9), not Precision\'s 7', (tester) async {
      await pumpSetup(tester);
      await tap(tester, find.byKey(const Key('playGame-precision')));
      await tap(tester, find.byKey(const Key('playGame-scoring')));
      expect(tester.widget<SegmentedButton<int>>(find.byKey(const Key('playRounds'))).selected, {9});
    });
  });

  group('the score pad, Precision for one player', () {
    Future<void> open(WidgetTester tester) async {
      await pumpSetup(tester);
      await tap(tester, find.byKey(const Key('playGame-precision')));
      await start(tester);
    }

    testWidgets('says where to throw from: round 1 from 3 m', (tester) async {
      await open(tester);
      expect(text(tester, 'padHeadline'), 'Your turn');
      expect(text(tester, 'padWhere'), 'Round 1 of 7: from 3 m');
    });

    testWidgets('has buttons 5 to 1 and Miss, and a safety line', (tester) async {
      await open(tester);
      for (final s in [5, 4, 3, 2, 1, 0]) {
        expect(find.byKey(Key('pad$s')), findsOneWidget);
      }
      expect(find.text('Miss'), findsOneWidget);
      expect(text(tester, 'padSafety'), contains('when no one is throwing'));
    });

    testWidgets('three knives: collect, then round 2 from 5 m', (tester) async {
      await open(tester);
      await score(tester, 4, times: 3);
      expect(text(tester, 'padHeadline'), 'Collect your knives');
      expect(text(tester, 'padWhere'), 'When no one is throwing.');
      await score(tester, 5);
      expect(text(tester, 'padWhere'), 'Round 2 of 7: from 5 m');
      expect(text(tester, 'playerDetail0'), 'Rounds: 3 m: 12, 5 m: 5');
    });

    testWidgets('21 knives end it: the total, kept in History as Precision', (tester) async {
      await open(tester);
      await score(tester, 3, times: 21);
      await tester.pump();
      expect(text(tester, 'padHeadline'), 'Game over! 63');
      expect(find.byKey(const Key('pad5')), findsNothing);
      expect(history.games.single.type, GameType.precision);
      expect(history.games.single.liveTest, isFalse);
    });

    testWidgets('a Miss scores 0', (tester) async {
      await open(tester);
      await score(tester, 0);
      expect(container.read(gameProvider).players.single.rounds.single.throws.single.score, 0);
    });

    testWidgets('New game starts Precision again', (tester) async {
      await open(tester);
      await score(tester, 1, times: 21);
      await tap(tester, find.byKey(const Key('padNewGame')));
      expect(text(tester, 'padWhere'), 'Round 1 of 7: from 3 m');
      expect(container.read(gameProvider).type, GameType.precision);
    });
  });

  group('the score pad, Three targets for two players', () {
    Future<void> open(WidgetTester tester) async {
      await pumpSetup(tester, kept: ['Mark', 'Nigel']);
      await tap(tester, find.byKey(const Key('playGame-threeTargets')));
      await tap(tester, find.text('2 players'));
      await tap(tester, find.text('3'));
      await start(tester);
    }

    testWidgets('Mark first, at target 1, then 2', (tester) async {
      await open(tester);
      expect(text(tester, 'padHeadline'), "Mark's turn");
      expect(text(tester, 'padWhere'), 'Round 1 of 3: at target 1');
      await score(tester, 5);
      expect(text(tester, 'padWhere'), 'Round 1 of 3: at target 2');
    });

    testWidgets('after Mark\'s 3 knives: collect, then Nigel\'s turn at target 1', (tester) async {
      await open(tester);
      await score(tester, 5, times: 3);
      expect(text(tester, 'padHeadline'), 'Collect your knives');
      expect(text(tester, 'padWhere'), "When no one is throwing. Then Nigel's turn.");
      await score(tester, 2);
      expect(text(tester, 'padHeadline'), "Nigel's turn");
      expect(text(tester, 'padWhere'), 'Round 1 of 3: at target 2');
    });

    testWidgets('the higher total wins: "Mark wins"', (tester) async {
      await open(tester);
      for (var round = 0; round < 3; round++) {
        await score(tester, 5, times: 3);
        await score(tester, 1, times: 3);
      }
      expect(text(tester, 'padHeadline'), 'Mark wins');
      expect(text(tester, 'playerTitle0'), 'Mark: 45');
      expect(text(tester, 'playerTitle1'), 'Nigel: 9');
    });

    testWidgets('Finish game asks first, then ends it with the rounds played', (tester) async {
      await open(tester);
      await score(tester, 4, times: 6);
      await tester.tap(find.byKey(const Key('finishGame')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('finishGameConfirm')));
      await tester.pumpAndSettle();
      expect(text(tester, 'padHeadline'), 'A draw');
      expect(find.textContaining('judged on 1 of 3 rounds'), findsOneWidget);
    });

    testWidgets('a score can be changed by tapping its slot', (tester) async {
      await open(tester);
      await score(tester, 2);
      await tester.tap(find.byKey(const Key('slot-0-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pickScore5')));
      await tester.pumpAndSettle();
      expect(container.read(gameProvider).players.first.total, 5);
    });
  });

  group('the headline and where-to texts', () {
    test('one player\'s finished Three targets game: "Game over!" and the total', () {
      var m = Match(PlayMode.solo, rules: const GameSession(maxRounds: 3), type: GameType.threeTargets);
      for (var i = 0; i < 9; i++) {
        m = m.byHand(2);
      }
      expect((padHeadline(m), padWhere(m)), ('Game over! 18', null));
    });
  });
}
