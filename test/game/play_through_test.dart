import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/game/throw_tracker.dart';
import 'package:thrower_app/game/throw_watcher.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/entry_point.dart';
import 'package:thrower_app/vision/luma_image.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/target_locator.dart';
import 'package:thrower_app/vision/throw_classifier.dart';

import '../vision/motion_detector_test.dart' show Fixture;

RgbImage full(String name) => decodeToRgb(File('test/fixtures/entry/$name').readAsBytesSync())!;

void main() {
  test('a whole round from recorded frames: 4, 3, bounce-out (0), then collecting → round 1 = 7', () {
    // Calibrate on the full-resolution board (as the app does when locked).
    final board = full('throw-stick-ring4-before.jpg');
    final found = buildTargetLocator(const [0.2, 0.4, 0.6, 0.8]).locate(board) as TargetFound;
    final calibration = TargetCalibration(
      imageWidth: board.width,
      imageHeight: board.height,
      boundaries: found.boundaries,
      outer: found.outer,
    );

    // The four rendered sequences back to back: each starts as the last ends.
    final frames = <LumaImage>[
      for (final name in ['throw-stick-ring4', 'throw-stick-ring3', 'throw-bounce-out', 'retrieve-knives'])
        ...Fixture(name).frames,
    ];
    // Full-resolution before/after for each knife that sticks, in order.
    final pictures = [
      (full('throw-stick-ring4-before.jpg'), full('throw-stick-ring4-after.jpg')),
      (full('throw-stick-ring3-before.jpg'), full('throw-stick-ring3-after.jpg')),
    ];

    final detector = MotionDetector(WatchRegion.fromCalibration(calibration));
    final tracker = ThrowTracker(calibration);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final game = container.read(gameProvider.notifier);
    final kinds = <ThrowOutcomeKind>[];
    var stuck = 0;

    for (var i = 0; i < frames.length; i++) {
      final episode = detector.add(frames[i], Duration(microseconds: (i * 1e6 / 15).round())).finished;
      if (episode == null) continue;
      final (outcome, knifeId) = tracker.onEpisode(episode);
      kinds.add(outcome.kind);
      EntryEstimate? entry;
      if (outcome.kind == ThrowOutcomeKind.stuck) {
        final (before, after) = pictures[stuck++];
        entry = GeometricEntryEstimator().estimate(before, after, calibration);
      }
      game.onEvent(ThrowEvent(outcome, episode, entry: entry, knifeId: knifeId), calibration);
    }

    expect(kinds, [ThrowOutcomeKind.stuck, ThrowOutcomeKind.stuck, ThrowOutcomeKind.bounceOut, ThrowOutcomeKind.boardVisit]);
    final session = container.read(gameProvider);
    expect(session.rounds, hasLength(1));
    expect([for (final t in session.rounds.single.throws) t.score], [4, 3, 0]);
    expect([for (final t in session.rounds.single.throws) t.result],
        [ThrowResult.stuck, ThrowResult.stuck, ThrowResult.bounceOut]);
    expect(session.total, 7);
    expect(session.roundComplete, isTrue);
    expect(tracker.knifeIds, isEmpty, reason: 'collecting the knives forgets them');
  });
}
