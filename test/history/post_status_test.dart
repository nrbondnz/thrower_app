import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/history/game_record.dart';
import 'package:thrower_app/history/post_status.dart';
import 'package:thrower_app/leaderboard/leaderboard_week.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/game_type.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/scoring/target_model.dart';

/// Thursday of the first leaderboard week (it started Friday 2026-10-23).
final now = DateTime.utc(2026, 10, 29, 12);

const p = TargetPoint(0.1, 0);

/// One thrower's session of [type], [rounds] long, [knives] a round (4s),
/// played with the camera; then [change] applied.
Match played(GameType type, {int rounds = 5, int knives = 3, Match Function(Match)? change, PlayMode? mode}) {
  var m = Match(mode ?? PlayMode.solo, rules: GameSession(maxRounds: rounds), type: type);
  for (var r = 0; r < rounds; r++) {
    for (var k = 0; k < knives; k++) {
      m = m.stuck(4, p);
    }
    m = m.boardVisited();
  }
  return change == null ? m : change(m);
}

GameRecord kept(Match m, {DateTime? at, String? recording}) =>
    GameRecord.fromMatch(m, at: at ?? now.subtract(const Duration(hours: 1)), recording: recording);

void main() {
  group('the status of a kept session', () {
    final cases = <(String, GameRecord, PostStatus)>[
      ('a full Ranked session this week', kept(played(GameType.ranked)), PostStatus.canPost),
      ('a normal 5 × 3 session with no hand changes', kept(played(GameType.scoring)), PostStatus.canPost),
      (
        'a Ranked session with a 0 set by hand (strict mode allows it)',
        kept(played(GameType.ranked, change: (m) => m.setScore(0, 0, 0, 0))),
        PostStatus.canPost,
      ),
      (
        'a normal session with a score changed by hand',
        kept(played(GameType.scoring, change: (m) => m.setScore(0, 0, 0, 5))),
        const PostStatus(PostState.cannotPost, NotPostable.changedByHand),
      ),
      (
        'a normal session with a 0 changed by hand',
        kept(played(GameType.scoring, change: (m) => m.setScore(0, 0, 0, 0))),
        const PostStatus(PostState.cannotPost, NotPostable.changedByHand),
      ),
      (
        'a normal session of 9 rounds',
        kept(played(GameType.scoring, rounds: 9)),
        const PostStatus(PostState.cannotPost, NotPostable.notThisGame),
      ),
      (
        'a round collected after 2 knives',
        kept(played(GameType.ranked, knives: 2)),
        const PostStatus(PostState.cannotPost, NotPostable.notFull),
      ),
      (
        'two throwers',
        kept(played(GameType.scoring, mode: PlayMode.twoTargets)),
        const PostStatus(PostState.cannotPost, NotPostable.twoThrowers),
      ),
      (
        'on a Live test recording',
        kept(played(GameType.ranked), recording: 'Target 1'),
        const PostStatus(PostState.cannotPost, NotPostable.liveTest),
      ),
      (
        'on the score pad',
        kept(played(GameType.precision, rounds: 7)),
        const PostStatus(PostState.cannotPost, NotPostable.scorePad),
      ),
      (
        'thrown last week',
        kept(played(GameType.ranked), at: DateTime.utc(2026, 10, 22, 23)),
        const PostStatus(PostState.cannotPost, NotPostable.earlierWeek),
      ),
    ];
    for (final (name, game, expected) in cases) {
      test(name, () => expect(postStatusOf(game, now), expected));
    }

    test('a session finished early, before its last round', () {
      var m = Match(PlayMode.solo, rules: const GameSession(maxRounds: 5), type: GameType.ranked);
      for (var k = 0; k < 3; k++) {
        m = m.stuck(4, p);
      }
      expect(postStatusOf(kept(m.finish()), now), const PostStatus(PostState.cannotPost, NotPostable.notFull));
    });

    test('posted', () {
      expect(postStatusOf(kept(played(GameType.ranked)).markedPosted(), now), PostStatus.posted);
    });

    test('kept before hand changes were recorded', () {
      final json = kept(played(GameType.ranked)).toJson()..remove('changedByHand');
      expect(
        postStatusOf(GameRecord.fromJson(json), now),
        const PostStatus(PostState.cannotPost, NotPostable.keptBefore),
      );
    });
  });

  group('kept with the session', () {
    test('hand changes, posted and test survive JSON', () {
      final g = kept(played(GameType.scoring, change: (m) => m.setScore(0, 0, 0, 5))).markedPosted();
      final back = GameRecord.fromJson(jsonDecode(jsonEncode(g.toJson())));
      expect((back.changedByHand, back.posted, back.test), (true, true, false));
    });

    test('a session not posted writes no "posted"', () {
      expect(kept(played(GameType.ranked)).toJson().containsKey('posted'), isFalse);
    });
  });

  group('the leaderboard week', () {
    test('weeks run from Friday 2026-10-23', () {
      expect(weekStartOf(DateTime.utc(2026, 10, 30, 1)), DateTime.utc(2026, 10, 30));
      expect(weekStartOf(DateTime.utc(2026, 10, 29, 23)), DateTime.utc(2026, 10, 23));
    });

    test('the same week, or not', () {
      expect(sameWeek(DateTime.utc(2026, 10, 23, 1), now), isTrue);
      expect(sameWeek(DateTime.utc(2026, 10, 30, 1), now), isFalse);
    });
  });

  group('posting at the end of a session', () {
    test('a normal 5 × 3 session with no hand changes can be posted', () {
      expect(played(GameType.scoring).postable, isTrue);
    });

    test('not with a score changed by hand', () {
      expect(played(GameType.scoring, change: (m) => m.setScore(0, 0, 0, 5)).postable, isFalse);
    });

    test('not a normal session of 3 rounds', () {
      expect(played(GameType.scoring, rounds: 3).postable, isFalse);
    });
  });

  // Traceability (2026-10-23): what counts as a hand change. A knife that
  // fell out, or a "?" (stuck, where it went in not found), is what the
  // camera saw, not a score set by hand.
  group('changed by hand, or not', () {
    /// A normal 5 × 3 session whose first knife is a "?" (scores 0).
    Match withUnscored() {
      var m = Match(PlayMode.solo, rules: const GameSession(maxRounds: 5), type: GameType.scoring);
      for (var r = 0; r < 5; r++) {
        for (var k = 0; k < 3; k++) {
          m = r == 0 && k == 0 ? m.stuck(4, null) : m.stuck(4, p);
        }
        m = m.boardVisited();
      }
      return m;
    }

    /// A session of [type] whose round 2 was collected after 2 knives.
    Match shortRound(GameType type) {
      var m = Match(PlayMode.solo, rules: const GameSession(maxRounds: 5), type: type);
      for (var r = 0; r < 5; r++) {
        for (var k = 0; k < (r == 1 ? 2 : 3); k++) {
          m = m.stuck(4, p);
        }
        m = m.boardVisited();
      }
      return m;
    }

    // (name, session, changed by hand, postable at the end, History's status)
    final cases = <(String, Match, bool, bool, PostStatus)>[
      (
        'a knife that fell out (Ranked)',
        played(GameType.ranked, change: (m) => m.fellOut(0, 0, 0)),
        false,
        true,
        PostStatus.canPost,
      ),
      (
        'a knife that fell out (normal 5 × 3)',
        played(GameType.scoring, change: (m) => m.fellOut(0, 0, 0)),
        false,
        true,
        PostStatus.canPost,
      ),
      ('a "?" (normal 5 × 3)', withUnscored(), false, true, PostStatus.canPost),
      (
        'a missing knife added as 0 (Ranked: strict mode allows it)',
        shortRound(GameType.ranked).addToRound(0, 1, 0),
        true,
        true,
        PostStatus.canPost,
      ),
      (
        'a missing knife added as 0 (normal 5 × 3)',
        shortRound(GameType.scoring).addToRound(0, 1, 0),
        true,
        false,
        const PostStatus(PostState.cannotPost, NotPostable.changedByHand),
      ),
    ];
    for (final (name, m, changed, postable, status) in cases) {
      test('$name: at the end and in History', () {
        expect((m.changedByHand, m.postable, postStatusOf(kept(m), now)), (changed, postable, status));
      });
    }
  });
}
