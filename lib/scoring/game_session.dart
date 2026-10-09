import 'target_model.dart';

enum ThrowResult {
  /// Stuck in the board; scored where the blade went in.
  stuck,

  /// Hit and bounced off, or missed: 0.
  bounceOut,

  /// Stuck, then fell out before the knives were collected: 0 (assumed rule;
  /// see Design Decisions → Rounds and Scoring).
  fellOut,
}

class ThrowRecord {
  const ThrowRecord(this.result, this.score, {this.point});

  final ThrowResult result;
  final int score;

  /// Where the blade went in (normalised target coordinates), if it stuck and
  /// the entry was found. A stuck throw without one scores 0, shown as "?".
  final TargetPoint? point;

  /// Stuck, but where it went in couldn't be found.
  bool get unscored => result == ThrowResult.stuck && point == null;
}

class RoundRecord {
  const RoundRecord(this.throws, {this.closed = false});

  final List<ThrowRecord> throws;

  /// Closed by a board visit (knives collected), even if not all thrown.
  final bool closed;

  int get total => throws.fold(0, (sum, t) => sum + t.score);
}

/// A single-player game: [maxRounds] rounds (Nigel: 9) of [throwsPerRound]
/// throws (Nigel: 3). Immutable; every change returns a new session.
///
/// - A throw goes into the current round; if that round is full or closed, a
///   new round starts first (so throwing on without collecting still counts).
/// - A board visit (someone at the board: collecting knives) closes the
///   current round if it has any throws.
/// - A knife that falls out turns its throw into [ThrowResult.fellOut], 0.
/// - The game is over once round [maxRounds] is complete; later throws are
///   ignored until a new game.
class GameSession {
  const GameSession({this.throwsPerRound = 3, this.maxRounds = 9, this.rounds = const []});

  final int throwsPerRound;
  final int maxRounds;
  final List<RoundRecord> rounds;

  int get total => rounds.fold(0, (sum, r) => sum + r.total);

  RoundRecord? get currentRound => rounds.isEmpty ? null : rounds.last;

  /// The current round has all its throws (or was closed): time to collect.
  bool get roundComplete {
    final r = currentRound;
    return r != null && (r.closed || r.throws.length >= throwsPerRound);
  }

  /// The last round is complete: the game is over.
  bool get isOver => rounds.length >= maxRounds && roundComplete;

  GameSession _withRounds(List<RoundRecord> rounds) =>
      GameSession(throwsPerRound: throwsPerRound, maxRounds: maxRounds, rounds: rounds);

  GameSession _withThrow(ThrowRecord t) {
    if (isOver) return this;
    final open = rounds.isNotEmpty && !roundComplete;
    final current = open ? rounds.last.throws : const <ThrowRecord>[];
    return _withRounds([
      ...(open ? rounds.sublist(0, rounds.length - 1) : rounds),
      RoundRecord([...current, t]),
    ]);
  }

  GameSession stuck(int score, TargetPoint? point) =>
      _withThrow(ThrowRecord(ThrowResult.stuck, point == null ? 0 : score, point: point));

  GameSession bounceOut() => _withThrow(const ThrowRecord(ThrowResult.bounceOut, 0));

  /// Throw [throwIndex] of round [roundIndex] fell out: it now scores 0.
  GameSession fellOut(int roundIndex, int throwIndex) {
    final round = rounds[roundIndex];
    final throws = [...round.throws];
    throws[throwIndex] = ThrowRecord(ThrowResult.fellOut, 0, point: throws[throwIndex].point);
    final updated = [...rounds];
    updated[roundIndex] = RoundRecord(throws, closed: round.closed);
    return _withRounds(updated);
  }

  GameSession boardVisited() {
    final r = currentRound;
    if (r == null || r.closed || r.throws.isEmpty) return this;
    return _withRounds([...rounds.sublist(0, rounds.length - 1), RoundRecord(r.throws, closed: true)]);
  }
}
