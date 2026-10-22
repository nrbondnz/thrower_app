import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/history/game_record.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/game_type.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/scoring/target_model.dart';

/// A match of [type] for [mode], [rounds] long.
Match game(GameType type, {PlayMode mode = PlayMode.solo, int? rounds}) =>
    Match(mode, rules: GameSession(maxRounds: rounds ?? type.defaultRounds), type: type);

/// [m] with [scores] added by hand, one after another (the score pad).
Match thrown(Match m, List<int> scores) => scores.fold(m, (m, s) => m.byHand(s));

void main() {
  group('the game types', () {
    test('Scoring offers 3, 5 or 9 rounds; Precision 7; Three targets 3, 5 or 7', () {
      expect(GameType.scoring.roundChoices, [3, 5, 9]);
      expect(GameType.precision.roundChoices, [7]);
      expect(GameType.threeTargets.roundChoices, [3, 5, 7]);
    });

    test('each defaults to its longest game: 9, 7, 7 and Ranked 5 rounds', () {
      expect([for (final t in GameType.values) t.defaultRounds], [9, 7, 7, 5]);
    });

    test('Scoring and Ranked use the camera; Precision and Three targets are scored by hand', () {
      expect([for (final t in GameType.values) t.handScored], [false, true, true, false]);
    });

    test('Precision throws round by round from 3, 5, 7, 3, 4, 5 and 7 m', () {
      expect([for (var r = 0; r < 7; r++) GameType.precision.distanceOf(r)], [3, 5, 7, 3, 4, 5, 7]);
      expect(GameType.precision.distanceOf(7), isNull);
    });

    test('Three targets throws each round\'s knives at targets 1, 2 and 3', () {
      expect([for (var i = 0; i < 3; i++) GameType.threeTargets.targetOf(i)], [1, 2, 3]);
    });

    test('Scoring has no distance and no target', () {
      expect((GameType.scoring.distanceOf(0), GameType.scoring.targetOf(0)), (null, null));
    });
  });

  group('Precision, one player', () {
    test('21 knives in 7 rounds of 3 end the game, the total all of them', () {
      final m = thrown(game(GameType.precision), List.filled(21, 4));
      expect(m.isOver, isTrue);
      expect(m.players.single.rounds.length, 7);
      expect(m.countedTotals, [84]);
    });

    test('the next distance follows the rounds: 3 m for the first three knives, then 5 m', () {
      var m = game(GameType.precision);
      final seen = <int?>[];
      for (var i = 0; i < 6; i++) {
        seen.add(m.nextDistance);
        m = m.byHand(5);
      }
      expect(seen, [3, 3, 3, 5, 5, 5]);
    });

    test('the last round is from 7 m, and there is no distance once the game is over', () {
      final last = thrown(game(GameType.precision), List.filled(18, 3));
      expect(last.nextDistance, 7);
      expect(thrown(last, [3, 3, 3]).nextDistance, isNull);
    });
  });

  group('Precision, two players taking turns', () {
    test('both throw round 1 from 3 m, then round 2 from 5 m', () {
      var m = game(GameType.precision, mode: PlayMode.sharedTarget);
      final seen = <(int, int?)>[];
      for (var i = 0; i < 9; i++) {
        seen.add((m.nextThrowerAt(0), m.nextDistance));
        m = m.byHand(2);
      }
      expect(seen, [
        (0, 3), (0, 3), (0, 3), // Player 1, round 1
        (1, 3), (1, 3), (1, 3), // Player 2, round 1
        (0, 5), (0, 5), (0, 5), // Player 1, round 2
      ]);
    });

    test('42 knives end it; the higher total wins', () {
      var m = game(GameType.precision, mode: PlayMode.sharedTarget);
      for (var round = 0; round < 7; round++) {
        m = thrown(m, [5, 5, 5, 4, 4, 4]);
      }
      expect(m.isOver, isTrue);
      expect(m.countedTotals, [105, 84]);
      expect(m.winner, 0);
    });
  });

  group('Three targets', () {
    test('the next target goes 1, 2, 3, then back to 1 for the next round', () {
      var m = game(GameType.threeTargets, rounds: 3);
      final seen = <int?>[];
      for (var i = 0; i < 4; i++) {
        seen.add(m.nextTarget);
        m = m.byHand(1);
      }
      expect(seen, [1, 2, 3, 1]);
    });

    test('two players take turns: Player 2 starts again at target 1', () {
      var m = game(GameType.threeTargets, mode: PlayMode.sharedTarget, rounds: 3);
      m = thrown(m, [5, 4, 3]);
      expect((m.nextThrowerAt(0), m.nextTarget), (1, 1));
    });

    test('3 rounds of 3 knives end a one-player game of 3 rounds', () {
      final m = thrown(game(GameType.threeTargets, rounds: 3), List.filled(9, 2));
      expect(m.isOver, isTrue);
      expect(m.countedTotals, [18]);
    });

    test('no target once the game is over', () {
      final m = thrown(game(GameType.threeTargets, rounds: 3), List.filled(9, 2));
      expect(m.nextTarget, isNull);
    });

    test('a Scoring match has no next distance or target', () {
      final m = game(GameType.scoring);
      expect((m.nextDistance, m.nextTarget), (null, null));
    });
  });

  group('the type is kept', () {
    test('through names, finishing and turns', () {
      final m = thrown(game(GameType.threeTargets, mode: PlayMode.sharedTarget), [5, 5, 5, 1])
          .withNames(['Ann', 'Bo'])
          .finish();
      expect(m.type, GameType.threeTargets);
    });

    test('a new Match is Scoring unless given a type', () {
      expect(Match(PlayMode.solo).type, GameType.scoring);
    });
  });

  group('the History record (version 3)', () {
    final at = DateTime(2026, 10, 20, 15);

    test('records the type of a finished game', () {
      final r = GameRecord.fromMatch(thrown(game(GameType.precision), List.filled(21, 5)), at: at);
      expect((r.type, r.rounds), (GameType.precision, 7));
    });

    test('a Precision game reads back as Precision', () {
      final r = GameRecord.fromMatch(thrown(game(GameType.precision), List.filled(21, 5)), at: at);
      final back = GameRecord.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(back.type, GameType.precision);
      expect(back.players, r.players);
    });

    test('a Three targets game reads back as Three targets', () {
      final r = GameRecord.fromMatch(thrown(game(GameType.threeTargets, rounds: 3), List.filled(9, 1)), at: at);
      expect(GameRecord.fromJson(jsonDecode(jsonEncode(r.toJson()))).type, GameType.threeTargets);
    });

    test('a Ranked game reads back as Ranked', () {
      final r = GameRecord.fromMatch(game(GameType.ranked).byHand(0).finish(), at: at);
      expect(GameRecord.fromJson(jsonDecode(jsonEncode(r.toJson()))).type, GameType.ranked);
    });

    test('a Scoring game is written as before, with no "type"', () {
      final r = GameRecord.fromMatch(thrown(game(GameType.scoring, rounds: 3), List.filled(9, 1)), at: at);
      expect(r.toJson().containsKey('type'), isFalse);
    });

    test('a game kept before version 3 (no "type") reads as Scoring', () {
      final old = {
        'id': '1',
        'finishedAt': '2026-10-16T01:00:00.000Z',
        'mode': 'solo',
        'rounds': 3,
        'players': [
          [5, 6, 7]
        ],
      };
      expect(GameRecord.fromJson(old).type, GameType.scoring);
    });

    test('an unknown type (from a newer version of the app) can\'t be read', () {
      final newer = {
        'id': '1',
        'finishedAt': '2026-10-16T01:00:00.000Z',
        'mode': 'solo',
        'rounds': 3,
        'players': [
          [5, 6, 7]
        ],
        'type': 'blindfold',
      };
      expect(() => GameRecord.fromJson(newer), throwsFormatException);
    });
  });

  // Ranked (story-checkpoint-game-center-scores, Nigel 2026-10-22).
  group('Ranked', () {
    /// A ranked game with every throw stuck at [score].
    Match played(int score, {int rounds = 5}) {
      var m = game(GameType.ranked);
      for (var r = 0; r < rounds; r++) {
        for (var i = 0; i < 3; i++) {
          m = m.stuck(score, const TargetPoint(0.1, 0));
        }
        m = m.boardVisited();
      }
      return m;
    }

    test('5 rounds of 3 from 3 m, only 5 rounds offered', () {
      expect(GameType.ranked.roundChoices, [5]);
      expect([for (var r = 0; r < 6; r++) GameType.ranked.distanceOf(r)], [3, 3, 3, 3, 3, null]);
    });

    test('only Ranked is strict', () {
      expect([for (final t in GameType.values) t.strict], [false, false, false, true]);
    });

    group('strict mode: a score set or added by hand can only be 0', () {
      final m = game(GameType.ranked).stuck(3, const TargetPoint(0.1, 0));

      test('a stuck 3 can be marked a bounce-out (0)', () {
        expect(m.setScore(0, 0, 0, 0).players.first.total, 0);
      });

      test('a stuck 3 can\'t be raised to 5, or changed to 1', () {
        expect(identical(m.setScore(0, 0, 0, 5), m), isTrue);
        expect(identical(m.setScore(0, 0, 0, 1), m), isTrue);
      });

      test('a throw the camera missed can be added as 0, not as 4', () {
        expect(m.byHand(0).players.first.rounds.first.throws, hasLength(2));
        expect(identical(m.byHand(4), m), isTrue);
      });

      test('nor added as 2 to a round collected early', () {
        final collected = m.boardVisited();
        expect(identical(collected.addToRound(0, 0, 2), collected), isTrue);
        expect(collected.addToRound(0, 0, 0).players.first.rounds.first.throws, hasLength(2));
      });

      test('Scoring games are unchanged: any score can be set', () {
        final scoring = game(GameType.scoring).stuck(3, const TargetPoint(0.1, 0));
        expect(scoring.setScore(0, 0, 0, 5).players.first.total, 5);
        expect(scoring.byHand(4).players.first.total, 7);
      });
    });

    group('postable: a full ranked game by one player', () {
      test('all 5 rounds played: postable, its total 0–75', () {
        final m = played(5);
        expect((m.postable, m.players.first.total), (true, 75));
      });

      test('not while it is being played', () => expect(played(5, rounds: 4).postable, isFalse));

      test('not finished early', () => expect(played(5, rounds: 4).finish().postable, isFalse));

      test('a Scoring game of 5 rounds is not', () {
        var m = game(GameType.scoring, rounds: 5);
        for (var i = 0; i < 15; i++) {
          m = m.stuck(4, const TargetPoint(0.1, 0));
        }
        expect((m.isOver, m.postable), (true, false));
      });

      test('nor a ranked game for two players', () {
        expect(game(GameType.ranked, mode: PlayMode.sharedTarget).finish().postable, isFalse);
      });
    });
  });

  // Nigel, 2026-10-22: "5 sets of 3": every round needs its 3 throws.
  group('Ranked: every round needs 3 throws to post', () {
    /// 5 rounds of three 4s, but round 2 collected after 2 knives.
    Match shortRound() {
      var m = game(GameType.ranked);
      for (var r = 0; r < 5; r++) {
        for (var i = 0; i < (r == 1 ? 2 : 3); i++) {
          m = m.stuck(4, const TargetPoint(0.1, 0));
        }
        m = m.boardVisited();
      }
      return m;
    }

    test('a round collected early: the game is over but can\'t be posted', () {
      final m = shortRound();
      expect((m.isOver, m.postable), (true, false));
    });

    test('the missing knife added as 0: it can be posted', () {
      expect(shortRound().addToRound(0, 1, 0).postable, isTrue);
    });
  });
}
