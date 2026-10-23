import 'package:flutter/services.dart';
import 'package:games_services/games_services.dart';

import 'leaderboard_service.dart';

/// [LeaderboardService] on Apple Game Center, through the `games_services`
/// plugin (iPhone only here: Android isn't postable yet, backlog #21). The
/// leaderboards are set up in App Store Connect with [Leaderboard.id]s;
/// [Leaderboard.ranked3m] restarts each week (set up weekly, 2026-10-23), and a score goes to the
/// current week.
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

  /// The app's own iPhone code (`GameCenterTables` in `ios/Runner/AppDelegate.swift`): the
  /// plugin can't load last week's full table, and loads every player's
  /// photo, which isn't shown.
  static const channel = MethodChannel('thrower/game_center');

  @override
  Future<LeaderboardTable> loadTable(Leaderboard board, LeaderboardWeek week, {int count = 25}) async {
    try {
      final result = await channel.invokeMapMethod<Object?, Object?>('loadTable', {
        'leaderboardID': board.id,
        'previous': week == LeaderboardWeek.lastWeek,
        'count': count,
      });
      return result == null ? LeaderboardTable.empty : LeaderboardTable.fromMap(result);
    } on PlatformException catch (e) {
      if (e.code == 'signedOut') throw const LeaderboardSignedOut();
      rethrow;
    }
  }
}
