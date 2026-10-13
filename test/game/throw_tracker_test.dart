import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/game/throw_tracker.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/throw_classifier.dart';

import '../vision/motion_detector_test.dart' show Fixture;

void main() {
  final f = Fixture('throw-stick-ring4');
  final still = f.frames.first;

  /// An episode from [start] s to [settled] s on an unchanged board: someone
  /// at the board if [blocked], otherwise a knife-sized shape moving.
  MotionEpisode episode(double start, double settled, {bool blocked = false}) => MotionEpisode(
        startFrame: 0,
        settledFrame: 10,
        start: Duration(milliseconds: (start * 1000).round()),
        settled: Duration(milliseconds: (settled * 1000).round()),
        peakChange: 0.01,
        peakShape: 0.5,
        changeFromBefore: 0,
        wasBlocked: blocked,
        before: still,
        after: still,
        threshold: 12,
      );

  test('just after a board visit, a change is part of the visit (people walking back)', () {
    final tracker = ThrowTracker(f.calibration);
    expect(tracker.onEpisode(episode(5, 10, blocked: true)).$1.kind, ThrowOutcomeKind.boardVisit);
    expect(tracker.onEpisode(episode(11, 11.5)).$1.kind, ThrowOutcomeKind.boardVisit);
  });

  test('once the visit is 3 s past, the same change is a bounce-out again', () {
    final tracker = ThrowTracker(f.calibration);
    tracker.onEpisode(episode(5, 10, blocked: true));
    expect(tracker.onEpisode(episode(13.5, 14)).$1.kind, ThrowOutcomeKind.bounceOut);
  });

  test('a stuck knife just after a visit still counts', () {
    final tracker = ThrowTracker(f.calibration);
    tracker.onEpisode(episode(5, 10, blocked: true));
    final throwEpisode = f.run().single;
    final shifted = MotionEpisode(
      startFrame: throwEpisode.startFrame,
      settledFrame: throwEpisode.settledFrame,
      start: const Duration(seconds: 11),
      settled: const Duration(seconds: 12),
      peakChange: throwEpisode.peakChange,
      peakShape: throwEpisode.peakShape,
      changeFromBefore: throwEpisode.changeFromBefore,
      before: throwEpisode.before,
      after: throwEpisode.after,
      threshold: throwEpisode.threshold,
    );
    expect(tracker.onEpisode(shifted).$1.kind, ThrowOutcomeKind.stuck);
  });
}
