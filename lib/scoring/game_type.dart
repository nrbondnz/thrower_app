/// Which game Play is playing (more-game-types story, Nigel 2026-10-20).
/// Every type is rounds of 3 knives on 5-ring boards, scored the same way
/// (KATTA), the highest total winning; they differ in the number of rounds
/// and in where each knife is thrown from, or at.
enum GameType {
  /// Rounds of 3 at one target, from the same place: Play as it was.
  scoring(label: 'Scoring', roundChoices: [3, 5, 9]),

  /// 7 rounds of 3, each round from its own distance ([precisionDistances]).
  precision(label: 'Precision', roundChoices: [7]),

  /// Three targets side by side: each round, one knife at each, in order.
  threeTargets(label: 'Three targets', roundChoices: [3, 5, 7]),

  /// A ranked game (story-checkpoint-game-center-scores, Nigel 2026-10-22):
  /// 5 rounds of 3 from [rankedDistance], one player, scored by the camera,
  /// in [strict] mode; a full game can be posted to the leaderboard.
  ranked(label: 'Ranked: 5 × 3 at 3 m', roundChoices: [5]);

  const GameType({required this.label, required this.roundChoices});

  /// The name shown in the app.
  final String label;

  /// The game lengths offered, in rounds (Precision has just one).
  final List<int> roundChoices;

  /// The game's length unless chosen: the longest choice.
  int get defaultRounds => roundChoices.last;

  /// Scored by hand on a score pad (the camera comes later: Nigel,
  /// 2026-10-20, "We can worry about the camera later").
  bool get handScored => this == precision || this == threeTargets;

  /// Strict mode (Nigel, 2026-10-22: "they can only change scores to mark a
  /// bounce out but not to change scores to higher"): a score set or added
  /// by hand can only be 0.
  bool get strict => this == ranked;

  /// A round's last throw starts the next round by itself (Nigel,
  /// 2026-10-23: three bounce-outs leave nothing on the board to collect, so
  /// the camera never sees the knives collected). Other games offer Round
  /// done ([Match.canEndRound]).
  bool get movesOnByItself => this == ranked;

  /// Where round [round] (from 0) is thrown from, in metres: Precision's
  /// own distances, Ranked's [rankedDistance]; null for the other types, or
  /// past the last round.
  int? distanceOf(int round) => switch (this) {
        precision => precisionDistances.elementAtOrNull(round),
        ranked => round < defaultRounds ? rankedDistance : null,
        _ => null,
      };

  /// Three targets: which target (1 to 3) throw [index] of a round (from 0)
  /// goes at; null for the other types.
  int? targetOf(int index) => this == threeTargets ? index + 1 : null;
}

/// Where a ranked game is thrown from, in metres (the thrower's word).
const rankedDistance = 3;

/// Precision's distance for each round, in metres. Nigel listed eight
/// distances (3, 5, 7, 3, 4, 5, 6, 7 m) for seven rounds of three; these are
/// his guess at the seven ("lets guess at 3,5,7,3,4,5,7"), to confirm.
const precisionDistances = [3, 5, 7, 3, 4, 5, 7];
