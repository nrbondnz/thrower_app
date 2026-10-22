import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/history/game_record.dart';
import 'package:thrower_app/history/throw_stats.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/game_type.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/scoring/target_model.dart';

final at = DateTime(2026, 10, 23, 12);

/// One thrower's session of [rounds] (each a list of knife scores), as kept.
GameRecord session(List<List<int>> rounds, {GameType type = GameType.scoring, String? recording}) {
  var m = Match(
    PlayMode.solo,
    rules: GameSession(maxRounds: rounds.length),
    type: type,
  );
  for (final r in rounds) {
    for (final s in r) {
      m = m.stuck(s, const TargetPoint(0.1, 0));
    }
    m = m.boardVisited();
  }
  return GameRecord.fromMatch(m, at: at, recording: recording);
}

/// [g] as kept before 2026-10-23: round totals only.
GameRecord totalsOnly(GameRecord g) =>
    GameRecord(id: g.id, finishedAt: g.finishedAt, mode: g.mode, rounds: g.rounds, players: g.players, type: g.type);

void main() {
  group('each knife kept', () {
    test('a kept session has each knife\'s score, by round', () {
      expect(
        session([
          [5, 4, 0],
          [3, 3, 3],
        ]).knives,
        [
          [
            [5, 4, 0],
            [3, 3, 3],
          ],
        ],
      );
    });

    test('kept through JSON', () {
      final g = session([
        [5, 4, 0],
      ]);
      expect(GameRecord.fromJson(jsonDecode(jsonEncode(g.toJson()))).knives, g.knives);
    });

    test('a session kept before then reads with none', () {
      final json = totalsOnly(
        session([
          [1, 2, 3],
        ]),
      ).toJson();
      expect(json.containsKey('knives'), isFalse);
      expect(GameRecord.fromJson(json).knives, isNull);
    });

    test('knives that can\'t be read are dropped, not the session', () {
      final json =
          session([
              [1, 2, 3],
            ]).toJson()
            ..['knives'] = [
              ['x'],
            ];
      final g = GameRecord.fromJson(jsonDecode(jsonEncode(json)));
      expect(g.knives, isNull);
      expect(g.totals, [6]);
    });
  });

  group('ThrowStats', () {
    final a = session([
      [5, 4, 0],
      [5, 3, 1],
    ]); // 18 points, 6 knives, two 5s, 5 hits
    final b = session([
      [2, 2, 2],
    ]); // 6 points, 3 knives

    test('nothing kept: no sessions, and dashes', () {
      final s = ThrowStats.of(const []);
      expect((s.sessions, perKnifeText(s), hitRateText(s), s.bestRound), (0, '–', '–', null));
    });

    test('sessions and knives', () {
      final s = ThrowStats.of([a, b]);
      expect((s.sessions, s.knives, s.points), (2, 9, 24));
    });

    test('per knife: points over knives, to one place', () {
      expect(perKnifeText(ThrowStats.of([a, b])), '2.7'); // 24 / 9
    });

    test('5s: knives in the bull', () {
      expect(ThrowStats.of([a, b]).fives, 2);
    });

    test('hit rate: knives that scored, a 0 is thrown but not hit', () {
      expect(hitRateText(ThrowStats.of([a, b])), '89%'); // 8 / 9
    });

    test('best round, out of 15', () {
      expect(ThrowStats.of([a, b]).bestRound, 9);
    });

    test('best ranked: a full Ranked session only', () {
      final ranked = session(List.filled(5, [4, 4, 4]), type: GameType.ranked);
      expect(ThrowStats.of([a, ranked]).bestRanked, 60);
      expect(ThrowStats.of([a]).bestRanked, isNull);
    });

    test('Live test sessions don\'t count', () {
      final s = ThrowStats.of([
        a,
        session([
          [5, 5, 5],
        ], recording: 'Test'),
      ]);
      expect((s.sessions, s.fives), (1, 2));
    });

    test('sessions kept before each knife was: in sessions and best, not the knife stats', () {
      final s = ThrowStats.of([
        a,
        totalsOnly(
          session([
            [5, 5, 5],
          ]),
        ),
      ]);
      expect((s.sessions, s.withKnives, s.knives, s.bestRound, s.partial), (2, 1, 6, 15, true));
    });

    test('two throwers: both throwers\' knives count', () {
      var m = Match(PlayMode.twoTargets, rules: const GameSession(maxRounds: 1));
      for (var i = 0; i < 3; i++) {
        m = m.stuck(5, const TargetPoint(0, 0)).stuck(1, const TargetPoint(0.9, 0), board: 1);
      }
      expect(ThrowStats.of([GameRecord.fromMatch(m, at: at)]).knives, 6);
    });
  });
}
