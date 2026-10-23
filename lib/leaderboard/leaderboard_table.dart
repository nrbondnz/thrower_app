// A leaderboard's table for one week (backlog #22, Nigel 2026-10-22: "a best
// 3 meter score table … previous … results table"; weekly since the
// leaderboard was set up weekly, 2026-10-23).

/// Which week's table.
enum LeaderboardWeek {
  thisWeek('This week'),
  lastWeek('Last week');

  const LeaderboardWeek(this.label);

  final String label;
}

/// One row: a place, the player's Game Center nickname and their score.
class LeaderboardEntry {
  const LeaderboardEntry({required this.rank, required this.name, required this.score, this.isMe = false});

  /// From the map the iPhone code sends (`thrower/game_center` →
  /// `loadTable`): rank, name, score, me.
  factory LeaderboardEntry.fromMap(Map<Object?, Object?> m) => LeaderboardEntry(
    rank: (m['rank'] as num).toInt(),
    name: m['name'] as String? ?? '',
    score: (m['score'] as num).toInt(),
    isMe: m['me'] == true,
  );

  final int rank;
  final String name;
  final int score;

  /// The player on this phone.
  final bool isMe;
}

/// A week's table: the top [entries], and the player's own entry ([me],
/// null if they have no score that week).
class LeaderboardTable {
  const LeaderboardTable({this.entries = const [], this.me, this.weekStart});

  /// From the map the iPhone code sends: entries, me, start (milliseconds
  /// since 1970, UTC).
  factory LeaderboardTable.fromMap(Map<Object?, Object?> m) {
    final me = m['me'];
    final start = m['start'];
    return LeaderboardTable(
      entries: [for (final e in (m['entries'] as List<Object?>? ?? const [])) LeaderboardEntry.fromMap(e! as Map)],
      me: me is Map ? LeaderboardEntry.fromMap(me) : null,
      weekStart: start is num ? DateTime.fromMillisecondsSinceEpoch(start.toInt(), isUtc: true) : null,
    );
  }

  static const empty = LeaderboardTable();

  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? me;

  /// When this week began, as Game Center says (null if it didn't say).
  final DateTime? weekStart;

  bool get isEmpty => entries.isEmpty;

  /// The player is below the [entries] shown: their row goes under the
  /// table.
  bool get meBelow => me != null && !entries.any((e) => e.isMe);
}

/// The player isn't signed in to the leaderboard's service (Game Center).
class LeaderboardSignedOut implements Exception {
  const LeaderboardSignedOut();
}
