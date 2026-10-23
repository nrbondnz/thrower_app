/// The leaderboards a game can be posted to (story-checkpoint-game-center-
/// scores, Nigel 2026-10-22). [id] is the leaderboard's ID in App Store
/// Connect (Game Center), set up there to restart each week (2026-10-23).
/// The Leaderboards tab shows each one by its [title].
enum Leaderboard {
  /// 3 m, 5 rounds of 3 knives, scores 0–75: a Ranked session, or a normal
  /// one with no score changed by hand (Nigel, 2026-10-23).
  ranked3m(
    'ranked.3m.5x3',
    title: '3 m knives · 3 × 5',
    about: "This week's best: 5 rounds of 3 knives from 3 m. Starts again each week.",
  );

  const Leaderboard(this.id, {required this.title, required this.about});

  final String id;

  /// Its name in the app (Nigel: "3 meter knifes 3x5").
  final String title;

  /// A line under the [title].
  final String about;
}

/// Posting scores, independent of where they go (Apple Game Center on the
/// iPhone: `GameCenterLeaderboardService`). UI and game code depend on this
/// interface only; tests use a fake. Not available on Android yet (backlog
/// #21): the app then has no service and shows no Post score.
abstract interface class LeaderboardService {
  /// Signs the player in to the leaderboard's own account (Game Center),
  /// asking if needed; false if they aren't signed in afterwards.
  Future<bool> signIn();

  /// Posts [score] to [board]. Throws if it didn't go (no signal).
  Future<void> submit(Leaderboard board, int score);

  /// Opens the leaderboard's own screen at [board].
  Future<void> show(Leaderboard board);
}
