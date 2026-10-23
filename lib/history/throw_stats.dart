import '../scoring/game_type.dart';
import 'game_record.dart';

/// The stats over the sessions kept on the phone (app-design story, Nigel
/// 2026-10-23: "the total, best, 5s, hit rate and average per knife"), as
/// docs/thrower/AppDesign/History and Stats.md describes. Every thrower's
/// knives count together; sessions played on a Live test recording don't
/// count.
class ThrowStats {
  const ThrowStats({
    required this.sessions,
    required this.withKnives,
    required this.knives,
    required this.points,
    required this.fives,
    required this.hits,
    required this.bestRanked,
    required this.bestRound,
  });

  /// Works out the stats over [games].
  factory ThrowStats.of(Iterable<GameRecord> games) {
    var sessions = 0, withKnives = 0, knives = 0, points = 0, fives = 0, hits = 0;
    int? bestRanked, bestRound;
    int? better(int? best, int x) => best == null || x > best ? x : best;
    for (final g in games) {
      // Test sessions (Setup → Tools) aren't real throwing.
      if (g.liveTest || g.test) continue;
      sessions++;
      for (final rounds in g.players) {
        for (final r in rounds) {
          bestRound = better(bestRound, r);
        }
      }
      if (g.type == GameType.ranked && !g.finishedEarly) bestRanked = better(bestRanked, g.totals.single);
      final kept = g.knives;
      if (kept == null) continue;
      withKnives++;
      for (final score in kept.expand((p) => p).expand((r) => r)) {
        knives++;
        points += score;
        if (score == 5) fives++;
        if (score > 0) hits++;
      }
    }
    return ThrowStats(
      sessions: sessions,
      withKnives: withKnives,
      knives: knives,
      points: points,
      fives: fives,
      hits: hits,
      bestRanked: bestRanked,
      bestRound: bestRound,
    );
  }

  /// Sessions kept (not Live test).
  final int sessions;

  /// Of those, the ones with each knife kept (from 2026-10-23): the
  /// knife stats are over these only.
  final int withKnives;

  /// Knives thrown.
  final int knives;

  /// Their points.
  final int points;

  /// Knives in the bull.
  final int fives;

  /// Knives that scored 1 or more.
  final int hits;

  /// The best total of a full Ranked session (out of 75); null before one.
  final int? bestRanked;

  /// The best round total (out of 15); null before any round.
  final int? bestRound;

  /// Points per knife, 0 to 5; null before any knife.
  double? get perKnife => knives == 0 ? null : points / knives;

  /// Knives that scored, as a fraction of those thrown; null before any.
  double? get hitRate => knives == 0 ? null : hits / knives;

  /// Some sessions were kept before each knife was: the knife stats leave
  /// them out.
  bool get partial => withKnives < sessions;
}

/// "3.4": points per knife to one decimal place, "–" before any knife.
String perKnifeText(ThrowStats s) => s.perKnife?.toStringAsFixed(1) ?? '–';

/// "88%": the hit rate, "–" before any knife.
String hitRateText(ThrowStats s) => s.hitRate == null ? '–' : '${(s.hitRate! * 100).round()}%';
