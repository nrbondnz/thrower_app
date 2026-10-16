import 'dart:math' as math;

import 'target_model.dart';

enum ThrowResult {
  /// Stuck in the board; scored where the blade went in.
  stuck,

  /// Hit and bounced off, or missed: 0.
  bounceOut,

  /// Stuck, then fell out before the knives were collected: 0 (assumed rule;
  /// see Design Decisions → Rounds and Scoring).
  fellOut,

  /// Missed the board altogether, added by hand (the camera usually sees
  /// nothing): 0. Score corrections story, Nigel 2026-10-17.
  missed,
}

class ThrowRecord {
  const ThrowRecord(this.result, this.score, {this.point, this.corrected = false});

  final ThrowResult result;
  final int score;

  /// Where the blade went in (normalised target coordinates), if it stuck and
  /// the entry was found. A stuck throw without one scores 0, shown as "?".
  final TargetPoint? point;

  /// The score was set by hand (a dispute, or a throw the camera didn't
  /// see), not taken from where the camera saw the blade go in.
  final bool corrected;

  /// Stuck, but where it went in couldn't be found (and no one has set the
  /// score by hand).
  bool get unscored => result == ThrowResult.stuck && point == null && !corrected;

  /// A throw added by hand with [score]: 0 is a miss, more a stuck knife the
  /// camera didn't register.
  factory ThrowRecord.byHand(int score) =>
      ThrowRecord(score == 0 ? ThrowResult.missed : ThrowResult.stuck, score, corrected: true);

  /// This throw with its score set by hand to [score]; what the camera saw
  /// ([result], [point]) stays.
  ThrowRecord withScore(int score) => ThrowRecord(result, score, point: point, corrected: true);
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
/// - Any throw's score can be set by hand ([setScore]), and a throw the
///   camera didn't see added ([byHand], [addToRound]).
/// - The game is over once round [maxRounds] is complete, or when it's
///   [finish]ed early; later throws are ignored until a new game.
class GameSession {
  const GameSession({this.throwsPerRound = 3, this.maxRounds = 9, this.rounds = const [], this.finished = false});

  final int throwsPerRound;
  final int maxRounds;
  final List<RoundRecord> rounds;

  /// Ended with Finish game, possibly before round [maxRounds] (Nigel,
  /// 2026-10-17). A round in progress counts, with the throws made so far.
  final bool finished;

  int get total => rounds.fold(0, (sum, r) => sum + r.total);

  RoundRecord? get currentRound => rounds.isEmpty ? null : rounds.last;

  /// The current round has all its throws (or was closed): time to collect.
  bool get roundComplete {
    final r = currentRound;
    return r != null && (r.closed || r.throws.length >= throwsPerRound);
  }

  /// The last round is complete, or the game was finished: it's over.
  bool get isOver => finished || (rounds.length >= maxRounds && roundComplete);

  /// Finished before its last round: fewer rounds than [maxRounds], or the
  /// last one not complete.
  bool get finishedEarly => finished && !(rounds.length >= maxRounds && roundComplete);

  /// The knives have been collected (the current round is closed) and the
  /// game goes on: the next round is under way, though it has no throws yet.
  /// (Its record is only made by its first throw.)
  bool get awaitingNextRound => !isOver && (currentRound?.closed ?? false);

  /// The round being played (1-based): the next one as soon as the knives
  /// are collected, not only once its first throw lands.
  int get roundNumber => rounds.isEmpty ? 1 : rounds.length + (awaitingNextRound ? 1 : 0);

  /// The rounds already finished and collected (or, once the game is over,
  /// all of them), for the list of round totals.
  List<RoundRecord> get finishedRounds =>
      isOver || awaitingNextRound ? rounds : rounds.take(math.max(0, rounds.length - 1)).toList();

  GameSession _withRounds(List<RoundRecord> rounds) =>
      GameSession(throwsPerRound: throwsPerRound, maxRounds: maxRounds, rounds: rounds, finished: finished);

  /// Ends the game now, with the rounds played so far ([finished]).
  GameSession finish() =>
      isOver ? this : GameSession(throwsPerRound: throwsPerRound, maxRounds: maxRounds, rounds: rounds, finished: true);

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

  /// A throw the camera didn't see, added by hand, as the next throw (as a
  /// detected one would be): 0 is a miss.
  GameSession byHand(int score) => _withThrow(ThrowRecord.byHand(score));

  /// Throw [throwIndex] of round [roundIndex] now scores [score], set by
  /// hand. Allowed after the game is over too (a dispute at the end).
  GameSession setScore(int roundIndex, int throwIndex, int score) {
    final round = rounds[roundIndex];
    final throws = [...round.throws];
    throws[throwIndex] = throws[throwIndex].withScore(score);
    final updated = [...rounds];
    updated[roundIndex] = RoundRecord(throws, closed: round.closed);
    return _withRounds(updated);
  }

  /// Whether round [roundIndex] has room for another throw: fewer than
  /// [throwsPerRound] (the round in progress, or one collected early).
  bool hasRoomIn(int roundIndex) => rounds[roundIndex].throws.length < throwsPerRound;

  /// A throw the camera didn't see, added by hand to round [roundIndex]
  /// (one with room: [hasRoomIn]). The round stays closed if it was.
  GameSession addToRound(int roundIndex, int score) {
    if (!hasRoomIn(roundIndex)) return this;
    final round = rounds[roundIndex];
    final updated = [...rounds];
    updated[roundIndex] = RoundRecord([...round.throws, ThrowRecord.byHand(score)], closed: round.closed);
    return _withRounds(updated);
  }

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
