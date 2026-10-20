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
  threeTargets(label: 'Three targets', roundChoices: [3, 5, 7]);

  const GameType({required this.label, required this.roundChoices});

  /// The name shown in the app.
  final String label;

  /// The game lengths offered, in rounds (Precision has just one).
  final List<int> roundChoices;

  /// The game's length unless chosen: the longest choice.
  int get defaultRounds => roundChoices.last;

  /// Scored by hand on a score pad (the camera comes later: Nigel,
  /// 2026-10-20, "We can worry about the camera later").
  bool get handScored => this != scoring;

  /// Precision: where round [round] (from 0) is thrown from, in metres; null
  /// for the other types, or past the last round.
  int? distanceOf(int round) => this == precision ? precisionDistances.elementAtOrNull(round) : null;

  /// Three targets: which target (1 to 3) throw [index] of a round (from 0)
  /// goes at; null for the other types.
  int? targetOf(int index) => this == threeTargets ? index + 1 : null;
}

/// Precision's distance for each round, in metres. Nigel listed eight
/// distances (3, 5, 7, 3, 4, 5, 6, 7 m) for seven rounds of three; these are
/// his guess at the seven ("lets guess at 3,5,7,3,4,5,7"), to confirm.
const precisionDistances = [3, 5, 7, 3, 4, 5, 7];
