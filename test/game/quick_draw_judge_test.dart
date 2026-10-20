import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/game/quick_draw_judge.dart';
import 'package:thrower_app/game/quick_draw_watcher.dart';

const go = Duration(milliseconds: 2800);

/// A throw reaching its board [ms] after go (negative: before it).
QuickDrawThrow stuck(int ms, [int score = 5]) => QuickDrawThrow(
  impact: go + Duration(milliseconds: ms),
  stuck: true,
  score: score,
);
QuickDrawThrow stuckUnscored(int ms) => QuickDrawThrow(impact: go + Duration(milliseconds: ms), stuck: true);
/// A knife stuck in a board drawn round by finger: timed, never scored.
QuickDrawThrow stuckInArea(int ms) =>
    QuickDrawThrow(impact: go + Duration(milliseconds: ms), stuck: true, scored: false);
QuickDrawThrow bounced(int ms) => QuickDrawThrow(impact: go + Duration(milliseconds: ms), stuck: false);

void main() {
  // The rule (Nigel, 2026-10-14): the first knife to stick wins; a bounce-out
  // or a false start loses; neither sticking, nobody wins.
  final cases = <(String, List<QuickDrawThrow?>, int?, bool)>[
    ('both stick: the faster wins', [stuck(850), stuck(817)], 1, false),
    ('both stick, Player 1 faster', [stuck(700, 2), stuck(817)], 0, false),
    ('both stick on the same frame with the same score: a draw', [stuck(817), stuck(817)], null, true),
    // The tie-break (Nigel's brother, 2026-10-19): the same frame, the higher
    // score wins; a score that wasn't found can't decide.
    ('the same frame: the higher score wins', [stuck(817, 3), stuck(817, 4)], 1, false),
    ('the same frame: Player 1 higher', [stuck(817, 5), stuck(817, 2)], 0, false),
    ('the same frame, one score not found: a draw', [stuck(817, 5), stuckUnscored(817)], null, true),
    ('the same frame, a bounce-out still loses', [bounced(817), stuck(817, 1)], 1, false),
    ('one bounces: the other wins, even if slower', [bounced(700), stuck(900)], 1, false),
    ('the Quick draw clip: Player 1 bounced, Player 2 stuck', [bounced(850), stuck(817)], 1, false),
    ('both bounce: no winner', [bounced(800), bounced(810)], null, false),
    ('a false start loses, however fast', [stuck(-100), stuck(900)], 1, false),
    ('both false start: no winner', [stuck(-100), stuck(-50)], null, false),
    ('a knife exactly at go is not a false start', [stuck(0), stuck(500)], 0, false),
    ('no throw seen from one: the other wins if it stuck', [null, stuck(817)], 1, false),
    ('no throws: no winner', [null, null], null, false),
  ];
  for (final (name, throws, winner, draw) in cases) {
    test(name, () {
      final v = judgeQuickDraw(throws, go);
      expect((v.winner, v.draw), (winner, draw));
    });
  }

  test('each throw is timed from go', () {
    final v = judgeQuickDraw([bounced(850), stuck(817)], go);
    expect([for (final p in v.players) p.afterGo], const [Duration(milliseconds: 850), Duration(milliseconds: 817)]);
  });

  group('the result line', () {
    test('names the winner, their score and time, and what happened to the other', () {
      expect(
        verdictText(judgeQuickDraw([bounced(850), stuck(817)], go)),
        'Player 2 wins: stuck 5, 0.82 s after go. Player 1 bounced out.',
      );
    });

    test('a draw', () {
      expect(
        verdictText(judgeQuickDraw([stuck(817, 4), stuck(817, 4)], go)),
        'A draw: both stuck on the same frame with the same score. Player 1: 4, 0.82 s after go. Player 2: 4, 0.82 s after go.',
      );
    });

    test('a win on score says so', () {
      expect(
        verdictText(judgeQuickDraw([stuck(817, 4), stuck(817)], go)),
        'Player 2 wins on score: stuck 5, 0.82 s after go. Player 1: 4, 0.82 s after go.',
      );
    });

    test('no winner, with a false start', () {
      expect(
        verdictText(judgeQuickDraw([stuck(-100), bounced(800)], go)),
        'No winner. Player 1: false start. Player 2 bounced out.',
      );
    });
  });

  // Named-players story (2026-10-19).
  test('the result line uses the players\' names, Player N without one', () {
    expect(verdictText(judgeQuickDraw([bounced(850), stuck(817)], go), names: ['Jo', 'Sam']),
        'Sam wins: stuck 5, 0.82 s after go. Jo bounced out.');
    expect(verdictText(judgeQuickDraw([bounced(850), stuck(817)], go), names: ['Jo', null]),
        'Player 2 wins: stuck 5, 0.82 s after go. Jo bounced out.');
  });

  // Drawn boards (Mark, 2026-10-21): only the time counts.
  group('boards drawn round by finger', () {
    test('the faster wins', () {
      final v = judgeQuickDraw([stuckInArea(850), stuckInArea(817)], go);
      expect((v.winner, v.draw, v.byScore), (1, false, false));
    });

    test('the same frame is a draw: no score to break it', () {
      final v = judgeQuickDraw([stuckInArea(817), stuckInArea(817)], go);
      expect((v.winner, v.draw), (null, true));
    });

    test('a throw shows only its time', () {
      expect(judgedText(judgeQuickDraw([stuckInArea(817), null], go).players[0]), '0.82 s');
    });

    test('the result line has no scores', () {
      expect(
        verdictText(judgeQuickDraw([stuckInArea(850), stuckInArea(817)], go)),
        'Player 2 wins: stuck, 0.82 s after go. Player 1: stuck, 0.85 s after go.',
      );
    });

    test('a draw says so without mentioning a score', () {
      expect(
        verdictText(judgeQuickDraw([stuckInArea(817), stuckInArea(817)], go)),
        'A draw: both stuck on the same frame. Player 1: stuck, 0.82 s after go. Player 2: stuck, 0.82 s after go.',
      );
    });
  });
}
