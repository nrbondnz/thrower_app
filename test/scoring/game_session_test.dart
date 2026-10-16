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

  group('the round being played (backlog #12)', () {
    test('a full round not yet collected is still that round', () {
      final g = const GameSession().stuck(1, p).stuck(1, p).stuck(1, p);
      expect((g.roundNumber, g.awaitingNextRound, g.finishedRounds.length), (1, false, 0));
    });

    test('collected, the next round is under way before its first throw', () {
      final g = const GameSession().stuck(1, p).stuck(1, p).stuck(1, p).boardVisited();
      expect((g.roundNumber, g.awaitingNextRound, g.finishedRounds.length), (2, true, 1));
    });

    test('its first throw makes the round record; the number stays the same', () {
      final g = const GameSession().stuck(1, p).boardVisited().stuck(4, p);
      expect((g.roundNumber, g.awaitingNextRound, g.finishedRounds.length), (2, false, 1));
    });

    test('after the last round, collecting does not start a round 10', () {
      var g = const GameSession();
      for (var i = 0; i < 27; i++) {
        g = g.stuck(1, p);
      }
      g = g.boardVisited();
      expect((g.isOver, g.roundNumber, g.awaitingNextRound, g.finishedRounds.length), (true, 9, false, 9));
    });
  });

  test('a board visit with no throws in the round changes nothing', () {
    const g = GameSession();
    expect(identical(g.boardVisited(), g), isTrue);
    expect(g.awaitingNextRound, isFalse);
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

  // Finish game (Nigel, 2026-10-17).
  group('finished early', () {
    test('a round in progress counts, with the throws made so far', () {
      final g = const GameSession().stuck(4, p).stuck(3, p).stuck(5, p).stuck(2, p).finish();
      expect((g.isOver, g.finishedEarly, g.total), (true, true, 14));
      expect([for (final r in g.finishedRounds) r.total], [12, 2]);
    });

    test('throws after finishing are ignored', () {
      final g = const GameSession().stuck(4, p).finish().stuck(5, p);
      expect(g.total, 4);
    });

    test('a game already over is not changed, and not early', () {
      final g = const GameSession(maxRounds: 1).stuck(4, p).stuck(3, p).stuck(5, p);
      expect(g.finish().finished, isFalse);
      expect(g.finishedEarly, isFalse);
    });

    test('a knife falling out after finishing still scores 0', () {
      final g = const GameSession().stuck(4, p).finish().fellOut(0, 0);
      expect((g.isOver, g.total), (true, 0));
    });
  });

  // Score corrections story, Task 1 (Nigel, 2026-10-17).
  group('scores set by hand', () {
    test('a disputed score is replaced; the round and game totals follow', () {
      final g = const GameSession().stuck(4, p).stuck(3, p).setScore(0, 1, 5);
      expect([for (final t in g.rounds.single.throws) t.score], [4, 5]);
      expect(g.total, 9);
    });

    test('a corrected throw keeps what the camera saw, and is marked', () {
      final t = const GameSession().stuck(4, p).setScore(0, 0, 2).rounds.single.throws.single;
      expect((t.result, t.point, t.corrected), (ThrowResult.stuck, p, true));
    });

    test('a bounce-out can be scored, and a "?" knife gets its score', () {
      final g = const GameSession().bounceOut().stuck(4, null).setScore(0, 0, 3).setScore(0, 1, 2);
      expect(g.total, 5);
      expect(g.rounds.single.throws[1].unscored, isFalse);
    });

    test('a miss added by hand is a 0 throw in the round in progress', () {
      final g = const GameSession().stuck(4, p).byHand(0);
      final t = g.rounds.single.throws.last;
      expect((t.result, t.score, t.corrected), (ThrowResult.missed, 0, true));
      expect(g.rounds.single.throws, hasLength(2));
    });

    test('a knife the camera missed, added by hand, counts toward the round', () {
      final g = const GameSession().stuck(4, p).stuck(3, p).byHand(5);
      expect((g.roundComplete, g.total), (true, 12));
    });

    test('adding the last throw of the last round ends the game', () {
      final g = const GameSession(maxRounds: 1).stuck(4, p).stuck(3, p).byHand(0);
      expect(g.isOver, isTrue);
    });

    test('a round collected early takes a throw added later, and stays collected', () {
      final g = const GameSession().stuck(4, p).boardVisited().stuck(5, p).addToRound(0, 0);
      expect([for (final r in g.rounds) r.throws.length], [2, 1]);
      expect(g.rounds.first.closed, isTrue);
    });

    test('a full round takes no more throws', () {
      final g = const GameSession().stuck(4, p).stuck(3, p).stuck(5, p);
      expect(g.hasRoomIn(0), isFalse);
      expect(identical(g.addToRound(0, 5), g), isTrue);
    });

    test('a corrected knife that later falls out still scores 0', () {
      final g = const GameSession().stuck(4, p).setScore(0, 0, 5).fellOut(0, 0);
      expect(g.total, 0);
    });

    test('a score can be set after the game is over', () {
      final g = const GameSession(maxRounds: 1).stuck(4, p).stuck(3, p).stuck(5, p).setScore(0, 0, 1);
      expect((g.isOver, g.total), (true, 9));
    });
  });
}
