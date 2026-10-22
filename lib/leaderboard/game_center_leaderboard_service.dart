import 'package:games_services/games_services.dart';

import 'leaderboard_service.dart';

/// [LeaderboardService] on Apple Game Center, through the `games_services`
/// plugin (iPhone only here: Android isn't postable yet, backlog #21). The
/// leaderboards are set up in App Store Connect with [Leaderboard.id]s;
/// [Leaderboard.ranked3m] restarts each month, and a score goes to the
/// current month.
class GameCenterLeaderboardService implements LeaderboardService {
  @override
  Future<bool> signIn() async {
    try {
      await GameAuth.signIn();
    } catch (_) {
      // Cancelled, or Game Center is off: report whether they're signed in.
    }
    return GameAuth.isSignedIn;
  }

  @override
  Future<void> submit(Leaderboard board, int score) =>
      Leaderboards.submitScore(score: Score(iOSLeaderboardID: board.id, value: score));

  @override
  Future<void> show(Leaderboard board) => Leaderboards.showLeaderboards(iOSLeaderboardID: board.id);
}
