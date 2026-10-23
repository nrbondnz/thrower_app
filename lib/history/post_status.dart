import '../leaderboard/leaderboard_service.dart';
import '../leaderboard/leaderboard_week.dart';
import '../scoring/game_type.dart';
import 'game_record.dart';

/// Whether a kept session can go on the leaderboard (posting-from-history
/// story, Nigel 2026-10-23: "can be posted, posted, and cannot be posted").
enum PostState { canPost, posted, cannotPost }

/// A session's [state], and for [PostState.cannotPost] why not.
class PostStatus {
  const PostStatus(this.state, [this.reason]);

  static const canPost = PostStatus(PostState.canPost);
  static const posted = PostStatus(PostState.posted);

  final PostState state;
  final String? reason;

  /// "Can be posted", "Posted" or "Cannot be posted".
  String get label => switch (state) {
    PostState.canPost => 'Can be posted',
    PostState.posted => 'Posted',
    PostState.cannotPost => 'Cannot be posted',
  };

  @override
  bool operator ==(Object other) => other is PostStatus && other.state == state && other.reason == reason;

  @override
  int get hashCode => Object.hash(state, reason);

  @override
  String toString() => reason == null ? label : '$label: $reason';
}

/// Why sessions can't be posted, as History says it.
abstract final class NotPostable {
  static const liveTest = 'played on a Live test recording';
  static const scorePad = 'scored on the score pad';
  static const twoThrowers = 'two throwers';
  static const notThisGame = 'only 3 m, 5 rounds of 3 can be posted';
  static const keptBefore = 'kept before sessions could be posted from History';
  static const notFull = 'not a full 5 rounds of 3 knives';
  static const changedByHand = 'a score was changed by hand';
  static const earlierWeek = 'thrown in an earlier leaderboard week';
  static const testSession = 'a test session, in a build without the test tools';
}

/// [game]'s status at [now]: posted; or it can be posted if it's one
/// thrower's session with the camera, played to the end with 3 knives in
/// every round, either Ranked or a normal 5-round session with no score
/// changed by hand, thrown this leaderboard week ([sameWeek]).
///
/// A test session ([GameRecord.test]) can be posted only in a build with the
/// test tools ([testTools]), and then to the test leaderboard
/// ([leaderboardFor]).
PostStatus postStatusOf(GameRecord game, DateTime now, {bool testTools = false}) {
  if (game.posted) return PostStatus.posted;
  String? why() {
    if (game.test && !testTools) return NotPostable.testSession;
    if (game.liveTest) return NotPostable.liveTest;
    if (game.type.handScored) return NotPostable.scorePad;
    if (game.players.length != 1) return NotPostable.twoThrowers;
    final ranked = game.type == GameType.ranked;
    if (!ranked && !(game.type == GameType.scoring && game.rounds == 5)) return NotPostable.notThisGame;
    final knives = game.knives;
    final changed = game.changedByHand;
    if (knives == null || changed == null) return NotPostable.keptBefore;
    final rounds = knives.single;
    if (game.finishedEarly || rounds.length < game.rounds || rounds.any((r) => r.length < 3)) {
      return NotPostable.notFull;
    }
    // Ranked's strict mode allows only 0s by hand, so a change there is fine.
    if (!ranked && changed) return NotPostable.changedByHand;
    if (!sameWeek(game.finishedAt, now)) return NotPostable.earlierWeek;
    return null;
  }

  final reason = why();
  return reason == null ? PostStatus.canPost : PostStatus(PostState.cannotPost, reason);
}

/// Where [game] is posted: a test session to the test leaderboard, never
/// put live (Review Agent, 2026-10-23: Game Center has no sandbox for
/// TestFlight, so test scores would otherwise reach the real board).
Leaderboard leaderboardFor(GameRecord game) => game.test ? Leaderboard.test3m : Leaderboard.ranked3m;
