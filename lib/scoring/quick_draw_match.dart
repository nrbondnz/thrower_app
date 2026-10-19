/// A match of Quick draw between two players (Nigel's brother, 2026-10-19:
/// "always three rounds"; the European Duel Cup plays the same way). Each
/// round is won by one player or drawn; the player who wins more rounds wins.
/// Immutable; every change returns a new match.
///
/// - All [rounds] are thrown, even at 2–0, so both players throw alike; the
///   match can be [finish]ed early after any round instead.
/// - Level after the [rounds], extra rounds are thrown, one at a time, until
///   one is won (drawn extra rounds go on).
/// - Finished early and level, it's a draw.
class QuickDrawMatch {
  const QuickDrawMatch({this.rounds = 3, this.results = const [], this.finished = false});

  /// Rounds in a match, before any extra rounds.
  final int rounds;

  /// Each round's winner (0 for Player 1), or null for a drawn round
  /// (including one nobody won), in the order thrown.
  final List<int?> results;

  /// Ended early with [finish].
  final bool finished;

  /// Rounds each player has won, Player 1 first.
  List<int> get wins => [
    for (final p in [0, 1]) results.where((w) => w == p).length,
  ];

  bool get _level => wins[0] == wins[1];

  bool get isOver => finished || (results.length >= rounds && !_level);

  /// The round being thrown (1-based); after the end, the last one thrown.
  int get roundNumber => isOver ? results.length : results.length + 1;

  /// The round being thrown is an extra round (the match was level after
  /// [rounds]).
  bool get isExtraRound => !isOver && results.length >= rounds;

  /// The player who won the match, once it's over; null for a draw.
  int? get winner => isOver && !_level ? (wins[0] > wins[1] ? 0 : 1) : null;

  /// Over and level: only when finished early.
  bool get draw => isOver && _level;

  /// The player ahead so far, or null if level.
  int? get leader => _level ? null : (wins[0] > wins[1] ? 0 : 1);

  /// Records a round won by [winner] (null: drawn). Ignored once over.
  QuickDrawMatch add(int? winner) => isOver ? this : QuickDrawMatch(rounds: rounds, results: [...results, winner]);

  /// Ends the match on the rounds thrown so far. Ignored before the first
  /// round or once over.
  QuickDrawMatch finish() =>
      isOver || results.isEmpty ? this : QuickDrawMatch(rounds: rounds, results: results, finished: true);

  /// "2–1", Player 1's wins first.
  String get scoreText => '${wins[0]}–${wins[1]}';
}
