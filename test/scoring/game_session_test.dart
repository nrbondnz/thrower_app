import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/target_model.dart';

const p = TargetPoint(0.1, 0.1);

void main() {
  test('a new game has no rounds and scores 0', () {
    const g = GameSession();
    expect(g.rounds, isEmpty);
    expect(g.total, 0);
    expect(g.roundComplete, isFalse);
  });

  test('three throws make a complete round with their total', () {
    final g = const GameSession().stuck(4, p).stuck(3, p).bounceOut();
    expect(g.rounds, hasLength(1));
    expect([for (final t in g.rounds.single.throws) t.score], [4, 3, 0]);
    expect(g.rounds.single.total, 7);
    expect(g.roundComplete, isTrue);
  });

  test('throwing on after a full round starts the next round', () {
    final g = const GameSession().stuck(4, p).stuck(3, p).stuck(5, p).stuck(2, p);
    expect(g.rounds, hasLength(2));
    expect(g.rounds.last.total, 2);
    expect(g.total, 14);
  });

  test('a board visit closes a round early; the next throw starts a new round', () {
    final g = const GameSession().stuck(4, p).boardVisited().stuck(5, p);
    expect(g.rounds, hasLength(2));
    expect(g.rounds.first.closed, isTrue);
    expect(g.rounds.first.total, 4);
    expect(g.rounds.last.total, 5);
  });

  test('a board visit with no throws in the round changes nothing', () {
    const g = GameSession();
    expect(identical(g.boardVisited(), g), isTrue);
    final full = const GameSession().stuck(1, p).stuck(1, p).stuck(1, p).boardVisited();
    expect(identical(full.boardVisited(), full), isTrue);
  });

  test('a knife that falls out scores 0 and keeps its place', () {
    final g = const GameSession().stuck(4, p).stuck(3, p).fellOut(0, 0);
    expect(g.rounds.single.throws.first.result, ThrowResult.fellOut);
    expect(g.rounds.single.throws.first.score, 0);
    expect(g.rounds.single.total, 3);
  });

  test('a stuck knife whose entry was not found counts as a throw, unscored', () {
    final g = const GameSession().stuck(4, null);
    expect(g.rounds.single.throws.single.unscored, isTrue);
    expect(g.total, 0);
  });

  test('rounds of a different length', () {
    final g = const GameSession(throwsPerRound: 2).stuck(1, p).stuck(1, p).stuck(1, p);
    expect(g.rounds, hasLength(2));
  });

  group('9-round games', () {
    /// [n] full rounds of three 2s.
    GameSession fullRounds(int n) {
      var g = const GameSession();
      for (var i = 0; i < n * 3; i++) {
        g = g.stuck(2, p);
      }
      return g;
    }

    test('a new game is 9 rounds of 3', () {
      expect(const GameSession().maxRounds, 9);
      expect(const GameSession().throwsPerRound, 3);
    });

    test('the game is not over after 8 full rounds', () {
      expect(fullRounds(8).isOver, isFalse);
    });

    test('the game is over when round 9 has its 3 throws', () {
      final g = fullRounds(9);
      expect(g.isOver, isTrue);
      expect(g.total, 54);
    });

    test('the game is not over part-way through round 9', () {
      expect(fullRounds(8).stuck(2, p).isOver, isFalse);
    });

    test('collecting the knives early in round 9 ends the game', () {
      final g = fullRounds(8).stuck(5, p).boardVisited();
      expect(g.isOver, isTrue);
      expect(g.rounds.last.total, 5);
    });

    test('throws after the game is over are ignored', () {
      final g = fullRounds(9);
      expect(identical(g.stuck(5, p), g), isTrue);
      expect(identical(g.bounceOut(), g), isTrue);
    });

    test('a knife from round 9 that falls out after game over still scores 0', () {
      final g = fullRounds(9).fellOut(8, 2);
      expect(g.rounds.last.total, 4);
      expect(g.isOver, isTrue);
    });

    test('a shorter game keeps its length through every change', () {
      final g = const GameSession(maxRounds: 1).stuck(1, p).fellOut(0, 0).stuck(1, p).boardVisited();
      expect(g.maxRounds, 1);
      expect(g.isOver, isTrue);
    });
  });
}
