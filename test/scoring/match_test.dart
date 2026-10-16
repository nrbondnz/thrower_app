import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/scoring/target_model.dart';

const p = TargetPoint(0.1, 0);

/// Each player's round totals, e.g. [[7], [5]].
List<List<int>> rounds(Match m) => [
      for (final g in m.players) [for (final r in g.rounds) r.total]
    ];

/// [m] after a whole game on one target: each turn 3 knives of [score1] for
/// Player 1 or [score2] for Player 2, collected after each turn.
Match fullSharedGame(Match m, int score1, int score2) {
  for (var turn = 0; turn < 2 * m.maxRounds; turn++) {
    for (var i = 0; i < 3; i++) {
      m = m.stuck(turn.isEven ? score1 : score2, p);
    }
    m = m.boardVisited();
  }
  return m;
}

void main() {
  test('each mode has its number of players and targets', () {
    expect([for (final m in PlayMode.values) (m.players, m.targets)], [(1, 1), (2, 1), (2, 2)]);
    expect(Match(PlayMode.twoTargets).players, hasLength(2));
  });

  test('a new match is empty, with Player 1 to throw', () {
    final m = Match(PlayMode.sharedTarget);
    expect((m.isEmpty, m.turn, m.isOver, m.winner), (true, 0, false, null));
  });

  group('one player', () {
    test('plays as a single game', () {
      final m = Match(PlayMode.solo).stuck(4, p).bounceOut().boardVisited().stuck(5, p);
      expect(rounds(m), [
        [4, 5]
      ]);
      expect(m.players.single.rounds.first.closed, isTrue);
    });

    test('has no winner when over', () {
      var m = Match(PlayMode.solo, rules: const GameSession(maxRounds: 1)).stuck(1, p).stuck(1, p).stuck(1, p);
      expect((m.isOver, m.winner, m.draw), (true, null, false));
      m = m.stuck(5, p);
      expect(m.players.single.total, 3, reason: 'throws after the game is over are ignored');
    });
  });

  group('two players on one target', () {
    test('Player 1 throws first; the turn passes when the knives are collected', () {
      var m = Match(PlayMode.sharedTarget).stuck(4, p).stuck(3, p).stuck(2, p);
      expect(m.turn, 0, reason: 'the turn stays until the knives are collected');
      m = m.boardVisited();
      expect(m.turn, 1);
      m = m.stuck(5, p);
      expect(rounds(m), [
        [9],
        [5]
      ]);
    });

    test('collecting early ends the turn with fewer throws', () {
      final m = Match(PlayMode.sharedTarget).stuck(4, p).boardVisited().stuck(5, p);
      expect(rounds(m), [
        [4],
        [5]
      ]);
      expect(m.players[0].rounds.single.closed, isTrue);
    });

    test('a board visit before anyone throws keeps the turn', () {
      final m = Match(PlayMode.sharedTarget).boardVisited();
      expect((m.turn, m.turnThrows), (0, 0));
    });

    test('a 4th knife without collecting is the next player\'s', () {
      final m = Match(PlayMode.sharedTarget).stuck(1, p).stuck(1, p).stuck(1, p).stuck(5, p);
      expect(rounds(m), [
        [3],
        [5]
      ]);
      expect(m.turn, 1);
      expect(m.players[0].rounds.single.closed, isTrue, reason: "Player 1's turn is over");
    });

    test('Player 1 starts every round', () {
      var m = Match(PlayMode.sharedTarget);
      final starters = <int>[];
      for (var turn = 0; turn < 6; turn++) {
        if (turn.isEven) starters.add(m.turn);
        m = m.stuck(1, p).boardVisited();
      }
      expect(starters, [0, 0, 0]);
    });

    test('a knife falling out zeroes the throw of the player who threw it', () {
      final m = Match(PlayMode.sharedTarget).stuck(4, p).stuck(3, p).boardVisited().stuck(5, p).fellOut(0, 0, 1);
      expect(rounds(m), [
        [4],
        [5]
      ]);
      expect(m.players[0].rounds.single.throws[1].result, ThrowResult.fellOut);
    });

    test('over once both have played every round; the higher total wins', () {
      final m = fullSharedGame(Match(PlayMode.sharedTarget), 4, 5);
      expect(m.isOver, isTrue);
      expect([for (final g in m.players) g.total], [108, 135]);
      expect((m.winner, m.draw), (1, false));
    });

    test('not over after Player 1 finishes round 9: Player 2 throws it too', () {
      var m = Match(PlayMode.sharedTarget, rules: const GameSession(maxRounds: 1)).stuck(1, p).stuck(1, p).stuck(1, p);
      expect((m.players[0].isOver, m.isOver), (true, false));
      m = m.boardVisited();
      expect(m.turn, 1);
      m = m.stuck(2, p).stuck(2, p).stuck(2, p);
      expect((m.isOver, m.winner), (true, 1));
    });

    test('equal totals are a draw', () {
      final m = fullSharedGame(Match(PlayMode.sharedTarget), 3, 3);
      expect((m.isOver, m.winner, m.draw), (true, null, true));
    });

    test('throws after the match is over are ignored', () {
      final m = fullSharedGame(Match(PlayMode.sharedTarget), 3, 4);
      expect(m.stuck(5, p), same(m));
    });
  });

  group('two players on two targets', () {
    test('each board scores for its own player, at the same time', () {
      final m = Match(PlayMode.twoTargets).stuck(4, p, board: 0).stuck(5, p, board: 1).stuck(3, p, board: 0).bounceOut(board: 1);
      expect(rounds(m), [
        [7],
        [5]
      ]);
    });

    test('collecting at one board closes only that player\'s round', () {
      final m = Match(PlayMode.twoTargets).stuck(4, p, board: 0).stuck(5, p, board: 1).boardVisited(board: 1);
      expect([for (final g in m.players) g.rounds.single.closed], [false, true]);
    });

    test('over once both games are; one finishing first can\'t throw on', () {
      var m = Match(PlayMode.twoTargets, rules: const GameSession(maxRounds: 1));
      for (var i = 0; i < 3; i++) {
        m = m.stuck(5, p, board: 0);
      }
      expect((m.takesThrowAt(0), m.takesThrowAt(1), m.isOver), (false, true, false));
      for (var i = 0; i < 3; i++) {
        m = m.stuck(2, p, board: 1);
      }
      expect((m.isOver, m.winner), (true, 0));
    });
  });
}
