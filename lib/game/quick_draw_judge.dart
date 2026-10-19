import 'quick_draw_watcher.dart';

/// How one player's Quick draw went.
enum QuickDrawResult {
  /// No throw seen.
  none,

  /// The knife reached the board before "go": a loss.
  falseStart,

  /// The knife reached the board after "go" but didn't stick: a loss.
  bounced,

  /// The knife stuck, after "go".
  stuck,
}

/// One player's throw, judged against "go".
class JudgedThrow {
  const JudgedThrow(this.result, {this.afterGo, this.score});

  final QuickDrawResult result;

  /// From "go" to the knife reaching the board (negative for a false start);
  /// null with no throw.
  final Duration? afterGo;

  /// A stuck knife's score (null if its entry wasn't found).
  final int? score;
}

/// Who won a Quick draw, and how each player's throw went.
class QuickDrawVerdict {
  const QuickDrawVerdict(this.players, {this.winner, this.draw = false, this.byScore = false});

  /// In player order (Player 1 first).
  final List<JudgedThrow> players;

  /// The winning player's index, or null for a draw or no winner.
  final int? winner;

  /// Both knives stuck and reached their boards on the same frame, with the
  /// same score (or a score that wasn't found).
  final bool draw;

  /// Both knives stuck on the same frame and [winner]'s higher score decided.
  final bool byScore;
}

/// Judges a round of Quick draw (Nigel, 2026-10-14): **the first knife to
/// stick wins**. A bounce-out loses, and so does a knife that reaches its
/// board before [go] (a false start). If both stick, the one that reached its
/// board first wins; on the same frame the higher score wins (Nigel's brother,
/// 2026-10-19), and the same score, or a score that wasn't found, is a draw.
/// If neither sticks, nobody wins.
QuickDrawVerdict judgeQuickDraw(List<QuickDrawThrow?> throws, Duration go) {
  final players = [
    for (final t in throws)
      if (t == null)
        const JudgedThrow(QuickDrawResult.none)
      else
        JudgedThrow(
          t.impact < go
              ? QuickDrawResult.falseStart
              : t.stuck
              ? QuickDrawResult.stuck
              : QuickDrawResult.bounced,
          afterGo: t.impact - go,
          score: t.stuck ? t.score : null,
        ),
  ];
  final counted = [
    for (final (i, p) in players.indexed)
      if (p.result == QuickDrawResult.stuck) i,
  ];
  if (counted.isEmpty) return QuickDrawVerdict(players);
  counted.sort((a, b) => players[a].afterGo!.compareTo(players[b].afterGo!));
  if (counted.length > 1 && players[counted[0]].afterGo == players[counted[1]].afterGo) {
    final (a, b) = (players[counted[0]].score, players[counted[1]].score);
    if (a == null || b == null || a == b) return QuickDrawVerdict(players, draw: true);
    return QuickDrawVerdict(players, winner: a > b ? counted[0] : counted[1], byScore: true);
  }
  return QuickDrawVerdict(players, winner: counted.first);
}

/// "0.82 s" (time after go).
String afterGoText(Duration d) => '${(d.inMilliseconds / 1000).toStringAsFixed(2)} s';

/// The line under a player's board.
String judgedText(JudgedThrow p) => switch (p.result) {
  QuickDrawResult.none => 'no throw',
  QuickDrawResult.falseStart => 'false start',
  QuickDrawResult.bounced => '${afterGoText(p.afterGo!)} · bounced',
  QuickDrawResult.stuck => '${afterGoText(p.afterGo!)} · ${p.score ?? '?'}',
};

/// The result line, e.g. "Player 2 wins: stuck 5, 0.82 s after go. Player 1
/// bounced."; "wins on score" when both stuck on the same frame.
String verdictText(QuickDrawVerdict v) {
  String player(int i) => 'Player ${i + 1}';
  String what(int i) {
    final p = v.players[i];
    return switch (p.result) {
      QuickDrawResult.none => '${player(i)}: no throw seen.',
      QuickDrawResult.falseStart => '${player(i)}: false start.',
      QuickDrawResult.bounced => '${player(i)} bounced out.',
      QuickDrawResult.stuck => '${player(i)}: ${p.score ?? '?'}, ${afterGoText(p.afterGo!)} after go.',
    };
  }

  final others = [
    for (var i = 0; i < v.players.length; i++)
      if (i != v.winner) what(i),
  ].join(' ');
  final winner = v.winner;
  if (v.draw) return 'A draw: both stuck on the same frame with the same score. $others';
  if (winner == null) return 'No winner. $others';
  final w = v.players[winner];
  final how = v.byScore ? 'wins on score' : 'wins';
  return '${player(winner)} $how: stuck ${w.score ?? '?'}, ${afterGoText(w.afterGo!)} after go. $others';
}
