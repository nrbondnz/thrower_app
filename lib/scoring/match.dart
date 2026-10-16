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
/// - Over once every player's game is over; the highest total wins, and
///   equal totals are a draw.
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

  /// The winner (0 for Player 1) once a two-player match is over; null for
  /// one player, a draw, or a match still on.
  int? get winner {
    if (!isOver || players.length < 2) return null;
    final totals = [for (final p in players) p.total];
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
    final m = turnThrows >= throwsPerRound ? _passTurn() : this;
    return Match._(mode, _replaced(m.players, m.turn, add(m.players[m.turn])), m.turn, m.turnThrows + 1);
  }

  /// Ends this turn: its round is closed, and the next player whose game
  /// isn't over has the turn (round order, so Player 1 starts each round).
  Match _passTurn() {
    final closed = _replaced(players, turn, players[turn].boardVisited());
    var next = turn;
    for (var i = 1; i <= players.length; i++) {
      final p = (turn + i) % players.length;
      if (!closed[p].isOver) {
        next = p;
        break;
      }
    }
    return Match._(mode, closed, next, 0);
  }

  Match _with(int player, GameSession game) => Match._(mode, _replaced(players, player, game), turn, turnThrows);

  static List<GameSession> _replaced(List<GameSession> players, int index, GameSession game) =>
      List.unmodifiable([...players]..[index] = game);
}
