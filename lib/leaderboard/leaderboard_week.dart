/// The leaderboard's weeks (posting-from-history story, 2026-10-23). The
/// Ranked leaderboard `ranked.3m.5x3` is a recurring Game Center leaderboard
/// of one week, starting 2026-10-23 (set up on the Mac, build 11). Game
/// Center files a score in the week it's posted in, so only a session thrown
/// this week can be posted later (Nigel, 2026-10-23).
///
/// The start is taken as 00:00 UTC on 2026-10-23: to confirm in App Store
/// Connect (Leaderboards → the recurring leaderboard's start).
final rankedLeaderboardStart = DateTime.utc(2026, 10, 23);

/// How long each occurrence lasts.
const rankedLeaderboardPeriod = Duration(days: 7);

/// When the week containing [at] began.
DateTime weekStartOf(DateTime at, {DateTime? start, Duration period = rankedLeaderboardPeriod}) {
  final first = start ?? rankedLeaderboardStart;
  final since = at.toUtc().difference(first);
  // Before the first week: treat it as one long week ending at the start.
  if (since.isNegative) return DateTime.utc(0);
  final weeks = since.inMicroseconds ~/ period.inMicroseconds;
  return first.add(period * weeks);
}

/// Whether [thrown] is in the same leaderboard week as [now].
bool sameWeek(DateTime thrown, DateTime now) => weekStartOf(thrown) == weekStartOf(now);
