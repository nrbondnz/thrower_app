import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/game/quick_draw_judge.dart';
import 'package:thrower_app/game/quick_draw_watcher.dart';

const go = Duration(milliseconds: 2800);

/// A throw reaching its board [ms] after go (negative: before it).
QuickDrawThrow stuck(int ms, [int score = 5]) => QuickDrawThrow(impact: go + Duration(milliseconds: ms), stuck: true, score: score);
QuickDrawThrow bounced(int ms) => QuickDrawThrow(impact: go + Duration(milliseconds: ms), stuck: false);

void main() {
  // The rule (Nigel, 2026-10-14): the first knife to stick wins; a bounce-out
  // or a false start loses; neither sticking, nobody wins.
  final cases = <(String, List<QuickDrawThrow?>, int?, bool)>[
    ('both stick: the faster wins', [stuck(850), stuck(817)], 1, false),
    ('both stick, Player 1 faster', [stuck(700, 2), stuck(817)], 0, false),
    ('both stick on the same frame: a draw', [stuck(817), stuck(817)], null, true),
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
      expect(verdictText(judgeQuickDraw([bounced(850), stuck(817)], go)),
          'Player 2 wins: stuck 5, 0.82 s after go. Player 1 bounced out.');
    });

    test('a draw', () {
      expect(verdictText(judgeQuickDraw([stuck(817, 4), stuck(817)], go)),
          'A draw: both stuck on the same frame. Player 1: 4, 0.82 s after go. Player 2: 5, 0.82 s after go.');
    });

    test('no winner, with a false start', () {
      expect(verdictText(judgeQuickDraw([stuck(-100), bounced(800)], go)),
          'No winner. Player 1: false start. Player 2 bounced out.');
    });
  });
}
