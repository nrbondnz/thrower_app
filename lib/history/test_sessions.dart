import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../leaderboard/leaderboard_week.dart';
import '../scoring/game_type.dart';
import '../scoring/match.dart';
import 'game_record.dart';

/// Test builds only (posting-from-history story, Nigel 2026-10-23: "some test
/// history throw sets that are available to be posted"): a debug build, or
/// one built with `--dart-define=THROWER_TEST_TOOLS=true` (TestFlight; never
/// an App Store build). Setup → Tools then offers Add 10 test sessions.
const testToolsFlag = bool.fromEnvironment('THROWER_TEST_TOOLS');

/// Whether this build shows the test tools: a debug build, the **beta**
/// flavor (`flutter build … --flavor beta`; store-release hygiene,
/// 2026-10-23), or the older `THROWER_TEST_TOOLS` define. Never the
/// **store** flavor, whatever it was built with (Review Agent: a define can
/// be left over in Xcode's settings).
bool get testToolsEnabled => appFlavor != 'store' && (kDebugMode || appFlavor == 'beta' || testToolsFlag);

/// [count] new, random sessions that can be posted at [now]: one thrower,
/// 5 rounds of 3 knives from the camera, no score changed by hand, a mix of
/// Ranked and normal 5 × 3, each thrown at a different time this leaderboard
/// week. They're marked [GameRecord.test].
List<GameRecord> makeTestSessions(DateTime now, {Random? random, int count = 10}) {
  final rng = random ?? Random();
  final weekStart = weekStartOf(now);
  // From the week's start (or 6 days back, before the leaderboard began).
  final earliest = weekStart.year == 0 ? now.subtract(const Duration(days: 6)) : weekStart.toLocal();
  final span = now.difference(earliest).inSeconds;
  // A thrower's knife: mostly 2 to 5, a few 1s and 0s (bounce-outs).
  const weights = [0, 1, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5];
  final used = <int>{};
  return [
    for (var i = 0; i < count; i++)
      () {
        // Distinct times, so distinct ids, newest last.
        var seconds = span <= 0 ? 0 : rng.nextInt(span);
        while (!used.add(seconds)) {
          seconds++;
        }
        final at = earliest.add(Duration(seconds: seconds, microseconds: i));
        final type = rng.nextBool() ? GameType.ranked : GameType.scoring;
        final rounds = [
          for (var r = 0; r < 5; r++) [for (var k = 0; k < 3; k++) weights[rng.nextInt(weights.length)]],
        ];
        return GameRecord(
          id: '${at.microsecondsSinceEpoch}',
          finishedAt: at,
          mode: PlayMode.solo,
          rounds: 5,
          players: [
            [for (final r in rounds) r.fold(0, (a, b) => a + b)],
          ],
          type: type,
          knives: [rounds],
          changedByHand: false,
          test: true,
        );
      }(),
  ];
}
