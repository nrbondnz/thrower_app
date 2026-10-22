/// The leaderboards a game can be posted to (story-checkpoint-game-center-
/// scores, Nigel 2026-10-22). [id] is the leaderboard's ID in App Store
/// Connect (Game Center), set up there to restart each month.
enum Leaderboard {
  /// Ranked: 5 × 3 at 3 m (`GameType.ranked`), scores 0–75.
  ranked3m('ranked.3m.5x3');

  const Leaderboard(this.id);

  final String id;
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
