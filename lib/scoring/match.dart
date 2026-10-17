import 'game_session.dart';
import 'target_model.dart';

/// How Play is played, chosen on the setup screen after Home → Play (Nigel,
/// 2026-10-16).
enum PlayMode {
  /// One player on one target.
  solo(players: 1, targets: 1),

  /// Two players taking turns on one target: a player throws their knives,
  /// they're collected, then it's the other player's turn.
  sharedTarget(players: 2, targets: 1),

  /// Two players, a target each, throwing at the same time.
  twoTargets(players: 2, targets: 2);

  const PlayMode({required this.players, required this.targets});

  final int players;
  final int targets;
}

/// Where a throw is in a [Match]: the player, the round and the throw
/// (each from 0).
typedef ThrowSlot = ({int player, int round, int index});

/// A game of Play for one or two players: a [GameSession] each (players in
/// order, Player 1 first). Immutable; every change returns a new match.
///
/// - [PlayMode.twoTargets]: board N's throws, collections and falling-out
///   knives belong to player N only.
/// - [PlayMode.sharedTarget]: throws go to whoever's [turn] it is. The turn
///   passes when the knives are collected (a board visit) or, if the next
///   knife comes without collecting, once the turn already has all its
///   throws. Player 1 starts every round. A player whose game is over is
///   skipped.
/// - Over once every player's game is over, or when it's [finish]ed early;
///   the highest total over the [countedRounds] wins, and equal totals are a
///   draw.
class Match {
  Match(this.mode, {GameSession rules = const GameSession()})
      : players = List.unmodifiable(List.filled(mode.players, rules)),
        turn = 0,
        turnThrows = 0;

  const Match._(this.mode, this.players, this.turn, this.turnThrows);

  final PlayMode mode;

  /// Each player's game, Player 1 first.
  final List<GameSession> players;

  /// One target: whose turn it is (0 for Player 1). Always 0 otherwise.
  final int turn;

  /// One target: how many knives have been thrown this turn.
  final int turnThrows;

  int get throwsPerRound => players.first.throwsPerRound;
  int get maxRounds => players.first.maxRounds;

  /// No throws yet by anyone.
  bool get isEmpty => players.every((p) => p.rounds.isEmpty);

  bool get isOver => players.every((p) => p.isOver);

  /// Ended with Finish game before every round was played.
  bool get finishedEarly => players.any((p) => p.finishedEarly);

  /// Ends the match now for every player (Finish game): a round in progress
  /// counts with the throws made so far.
  Match finish() => Match._(mode, List.unmodifiable([for (final p in players) p.finish()]), turn, turnThrows);

  /// The rounds the result is judged on: as many as every player has played
  /// (Nigel, 2026-10-17: finished early, two players are judged on equal
  /// rounds). All of them for one player, or a match played to the end.
  int get countedRounds => players.map((p) => p.rounds.length).reduce((a, b) => a < b ? a : b);

  /// Each player's total over the [countedRounds].
  List<int> get countedTotals => [
        for (final p in players) p.rounds.take(countedRounds).fold(0, (sum, r) => sum + r.total),
      ];

  /// The winner (0 for Player 1) once a two-player match is over, on the
  /// [countedTotals]; null for one player, a draw, or a match still on.
  int? get winner {
    if (!isOver || players.length < 2) return null;
    final totals = countedTotals;
    final best = totals.reduce((a, b) => a > b ? a : b);
    return totals.where((t) => t == best).length == 1 ? totals.indexOf(best) : null;
  }

  /// A two-player match over with equal totals.
  bool get draw => isOver && players.length > 1 && winner == null;

  /// The player a throw at [board] counts for: the board's own on two
  /// targets, otherwise whoever's turn it is.
  int playerAt(int board) => mode == PlayMode.twoTargets ? board : turn;

  /// Whether a throw at [board] would still count (that player's game, or
  /// the shared target's match, isn't over).
  bool takesThrowAt(int board) => mode == PlayMode.twoTargets ? !players[board].isOver : !isOver;

  Match stuck(int score, TargetPoint? point, {int board = 0}) => _throw(board, (g) => g.stuck(score, point));

  Match bounceOut({int board = 0}) => _throw(board, (g) => g.bounceOut());

  /// The throw at [slot], or null if there's none there.
  ThrowRecord? throwAt(ThrowSlot slot) =>
      players[slot.player].rounds.elementAtOrNull(slot.round)?.throws.elementAtOrNull(slot.index);

  /// Where the last throw at [board] went: in its player's last round (one
  /// target: the player whose turn it is). Null before any.
  ThrowSlot? lastThrowAt(int board) {
    final player = playerAt(board);
    final rounds = players[player].rounds;
    if (rounds.isEmpty) return null;
    return (player: player, round: rounds.length - 1, index: rounds.last.throws.length - 1);
  }

  /// Who the next throw at [board] counts for: the board's own player on two
  /// targets; on one target, whoever's turn it is, or the next player once
  /// this turn has all its throws.
  int nextThrowerAt(int board) => mode == PlayMode.twoTargets ? board : (turnComplete ? nextTurn : turn);

  /// A throw the camera didn't see, added by hand at [board] as the next
  /// throw (one target: the player whose turn it is, counting toward the
  /// turn): 0 is a miss.
  Match byHand(int score, {int board = 0}) => _throw(board, (g) => g.byHand(score));

  /// [player]'s throw [throwIndex] of round [roundIndex] now scores [score],
  /// set by hand.
  Match setScore(int player, int roundIndex, int throwIndex, int score) =>
      _with(player, players[player].setScore(roundIndex, throwIndex, score));

  /// A throw added by hand to [player]'s earlier round [roundIndex], one
  /// collected early ([GameSession.hasRoomIn]).
  Match addToRound(int player, int roundIndex, int score) =>
      _with(player, players[player].addToRound(roundIndex, score));

  /// [player]'s throw [throwIndex] of round [roundIndex] fell out: 0.
  Match fellOut(int player, int roundIndex, int throwIndex) =>
      _with(player, players[player].fellOut(roundIndex, throwIndex));

  /// Someone at [board]: collecting the knives closes that player's round
  /// and, on one target, passes the turn (if this turn had any throws).
  Match boardVisited({int board = 0}) {
    if (mode != PlayMode.sharedTarget) return _with(board, players[board].boardVisited());
    return turnThrows == 0 ? this : _passTurn();
  }

  Match _throw(int board, GameSession Function(GameSession) add) {
    if (mode != PlayMode.sharedTarget) return _with(board, add(players[board]));
    if (isOver) return this;
    // Thrown on without collecting: the turn already had all its knives.
    final m = turnComplete ? _passTurn() : this;
    return Match._(mode, _replaced(m.players, m.turn, add(m.players[m.turn])), m.turn, m.turnThrows + 1);
  }

  /// One target: this turn has all its throws; the knives are to be
  /// collected before [nextTurn] throws.
  bool get turnComplete => mode == PlayMode.sharedTarget && turnThrows >= throwsPerRound;

  /// One target: who throws after this turn: the next player whose game
  /// isn't over once this turn's round is closed (round order, so Player 1
  /// starts each round).
  int get nextTurn => _nextAfter(_replaced(players, turn, players[turn].boardVisited()));

  /// The next throw at [board] starts a new round's (or, on one target, a
  /// new turn's) marks on the board.
  bool nextThrowStartsRound({int board = 0}) => mode == PlayMode.sharedTarget
      ? turnThrows == 0 || turnComplete
      : players[board].currentRound == null || players[board].roundComplete;

  /// Ends this turn: its round is closed, and [nextTurn] has the turn.
  Match _passTurn() {
    final closed = _replaced(players, turn, players[turn].boardVisited());
    return Match._(mode, closed, _nextAfter(closed), 0);
  }

  int _nextAfter(List<GameSession> closed) {
    for (var i = 1; i <= players.length; i++) {
      final p = (turn + i) % players.length;
      if (!closed[p].isOver) return p;
    }
    return turn;
  }

  Match _with(int player, GameSession game) => Match._(mode, _replaced(players, player, game), turn, turnThrows);

  static List<GameSession> _replaced(List<GameSession> players, int index, GameSession game) =>
      List.unmodifiable([...players]..[index] = game);
}
