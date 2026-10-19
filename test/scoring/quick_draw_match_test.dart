import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/scoring/quick_draw_match.dart';

/// A match after rounds won by [winners] (null: drawn), in order.
QuickDrawMatch after(List<int?> winners) => winners.fold(const QuickDrawMatch(), (m, w) => m.add(w));

void main() {
  // The rule (Nigel's brother, 2026-10-19): always three rounds; the player
  // who wins more rounds wins; level → extra rounds until one is won (Nigel);
  // the match can be finished early.
  final cases = <(String, List<int?>, bool, int?, bool)>[
    ('a new match is not over', [], false, null, false),
    ('2–1 after three rounds: Player 1 wins', [0, 1, 0], true, 0, false),
    ('2–0 after two rounds: the third is still thrown', [1, 1], false, null, false),
    ('2–0 then 1 more: Player 2 wins 3–0', [1, 1, 1], true, 1, false),
    ('1–1 and a drawn round: level, not over', [0, 1, null], false, null, false),
    ('three drawn rounds: level, not over', [null, null, null], false, null, false),
    ('level, then an extra round won: over', [0, 1, null, 1], true, 1, false),
    ('level, a drawn extra round goes on', [0, 1, null, null], false, null, false),
    ('1–0 and two drawn rounds: Player 1 wins', [0, null, null], true, 0, false),
  ];
  for (final (name, winners, over, winner, draw) in cases) {
    test(name, () {
      final m = after(winners);
      expect((m.isOver, m.winner, m.draw), (over, winner, draw));
    });
  }

  test('the round being thrown, and extra rounds', () {
    expect(after([]).roundNumber, 1);
    expect(after([0, 1]).roundNumber, 3);
    expect(after([0, 1, null]).roundNumber, 4);
    expect(after([0, 1, null]).isExtraRound, isTrue);
    expect(after([0, 1]).isExtraRound, isFalse);
  });

  test('once over, the round number stays at the last round and no more are added', () {
    final m = after([0, 1, 0]);
    expect(m.roundNumber, 3);
    expect(m.add(1).results, [0, 1, 0]);
  });

  test('wins, the score and the leader', () {
    final m = after([1, null]);
    expect(m.wins, [0, 1]);
    expect(m.scoreText, '0–1');
    expect(m.leader, 1);
    expect(after([0, 1]).leader, isNull);
  });

  group('finishing early', () {
    test('ahead: that player wins', () {
      final m = after([0]).finish();
      expect((m.isOver, m.winner, m.draw, m.finished), (true, 0, false, true));
    });

    test('level: a draw', () {
      final m = after([0, 1]).finish();
      expect((m.isOver, m.winner, m.draw), (true, null, true));
    });

    test('in extra rounds, level: a draw', () {
      expect(after([0, 1, null, null]).finish().draw, isTrue);
    });

    test('not before the first round', () {
      expect(const QuickDrawMatch().finish().isOver, isFalse);
    });

    test('rounds added after finishing are ignored', () {
      expect(after([0]).finish().add(1).results, [0]);
    });
  });
}
