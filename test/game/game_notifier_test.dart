import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/game/throw_watcher.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/ui/play_screen.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/entry_point.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/throw_classifier.dart';

/// Straight-on target: centre (500, 400), outer radius 200 px, ideal rings.
TargetCalibration calibration() {
  Ellipse at(double r) => Ellipse(cx: 500, cy: 400, semiMajor: 200 * r, semiMinor: 200 * r, angle: 0);
  return TargetCalibration(
    imageWidth: 1000,
    imageHeight: 800,
    boundaries: {for (final r in const [0.2, 0.4, 0.6, 0.8]) r: at(r)},
    outer: at(1.0),
  );
}

const episode = MotionEpisode(
  startFrame: 0,
  settledFrame: 5,
  start: Duration.zero,
  settled: Duration(seconds: 1),
  peakChange: 0.01,
  changeFromBefore: 0.007,
);

ThrowEvent stuckAt(double x, double y, int id) => ThrowEvent(
      const ThrowOutcome(ThrowOutcomeKind.stuck),
      episode,
      knifeId: id,
      entry: EntryEstimate(point: Point2(x, y), axis: const Point2(1, 0), knifePixels: 100),
    );

const tp = TargetPoint(0.1, 0);

ThrowEvent event(ThrowOutcomeKind kind, {int? id}) => ThrowEvent(ThrowOutcome(kind), episode, knifeId: id);

void main() {
  late ProviderContainer container;
  late GameNotifier game;
  final c = calibration();

  setUp(() {
    container = ProviderContainer();
    game = container.read(gameProvider.notifier);
  });
  tearDown(() => container.dispose());

  GameSession session() => container.read(gameProvider);

  test('scores a stuck knife where its blade went in', () {
    game.onEvent(stuckAt(500, 400 + 200 * 0.3, 0), c); // radius 0.3 → ring 4
    expect(session().rounds.single.throws.single.score, 4);
  });

  test('a stuck knife without an entry point is unscored', () {
    game.onEvent(ThrowEvent(const ThrowOutcome(ThrowOutcomeKind.stuck), episode, knifeId: 0), c);
    expect(session().rounds.single.throws.single.unscored, isTrue);
  });

  test('a knife that falls out turns its own throw into 0', () {
    game
      ..onEvent(stuckAt(500, 400, 0), c) // bull: 5
      ..onEvent(stuckAt(500 + 200 * 0.5, 400, 1), c) // ring 3
      ..onEvent(event(ThrowOutcomeKind.fellOut, id: 0), c);
    final throws = session().rounds.single.throws;
    expect(throws.first.result, ThrowResult.fellOut);
    expect(throws.first.score, 0);
    expect(throws.last.score, 3);
    expect(session().total, 3);
  });

  test('collecting the knives closes the round; a fall-out afterwards is ignored', () {
    game
      ..onEvent(stuckAt(500, 400, 0), c)
      ..onEvent(event(ThrowOutcomeKind.boardVisit), c)
      ..onEvent(event(ThrowOutcomeKind.fellOut, id: 0), c);
    expect(session().rounds.single.closed, isTrue);
    expect(session().total, 5);
  });

  test('a bounce-out scores 0; a new game starts again', () {
    game.onEvent(event(ThrowOutcomeKind.bounceOut), c);
    expect(session().rounds.single.throws.single.result, ThrowResult.bounceOut);
    game.newGame();
    expect(session().rounds, isEmpty);
  });

  test('after game over a stuck knife is ignored, so its falling out changes nothing', () {
    for (var i = 0; i < 27; i++) {
      game.onEvent(stuckAt(500, 400, i), c);
      if (i % 3 == 2) game.onEvent(event(ThrowOutcomeKind.boardVisit), c);
    }
    expect(session().isOver, isTrue);
    final over = session();
    game.onEvent(stuckAt(500, 400, 99), c);
    game.onEvent(event(ThrowOutcomeKind.fellOut, id: 99), c);
    expect(session(), same(over));
    expect(session().total, 135);
  });

  group('play screen text', () {
    test('an empty game', () {
      expect(roundText(const GameSession()), 'Round 1 of 9: – · – · –  (0)');
      expect(gameText(const GameSession()), 'Game total: 0');
    });

    test('a round in progress, with an unscored knife', () {
      final g = const GameSession().stuck(4, null).stuck(3, tp);
      expect(roundText(g), 'Round 1 of 9: ? · 3 · –  (3)');
    });

    test('a complete round asks to collect knives only when no one is throwing', () {
      final g = const GameSession().stuck(4, tp).stuck(3, tp).bounceOut();
      expect(gameText(g), contains('Round complete: 7. Collect your knives when no one is throwing.'));
    });

    test('previous rounds are listed', () {
      final g = const GameSession().stuck(4, tp).stuck(3, tp).bounceOut().stuck(5, tp);
      expect(roundText(g), 'Round 2 of 9: 5 · – · –  (5)');
      expect(gameText(g), contains('Rounds: 7'));
      expect(gameText(g), contains('Game total: 12'));
    });

    test('round 9 of 9', () {
      var g = const GameSession();
      for (var i = 0; i < 25; i++) {
        g = g.stuck(1, tp);
      }
      expect(roundText(g), 'Round 9 of 9: 1 · – · –  (1)');
    });

    test('game over shows the final total and every round', () {
      var g = const GameSession();
      for (var i = 0; i < 27; i++) {
        g = g.stuck(i < 3 ? 5 : 1, tp);
      }
      expect(gameText(g, message: 'Bounced off: 0.'),
          'Game over! Final total: 39\nRounds: 15, 3, 3, 3, 3, 3, 3, 3, 3\nCollect your knives when no one is throwing.');
    });

    test('state lines', () {
      expect(playStateText(WatchState.blocked), 'Someone is at the board.');
      expect(playStateText(WatchState.motion), startsWith('Throw seen'));
    });
  });

  test('the direction of a knife from the centre does not change its score', () {
    game.onEvent(stuckAt(500 + 200 * 0.3 * math.cos(1), 400 + 200 * 0.3 * math.sin(1), 9), c);
    expect(session().rounds.single.throws.single.score, 4);
  });
}
