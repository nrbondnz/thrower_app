import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/luma_image.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/throw_classifier.dart';

import 'motion_detector_test.dart' show Fixture;

void main() {
  final cases = <(String, ThrowOutcomeKind)>[
    ('throw-stick-ring4', ThrowOutcomeKind.stuck),
    ('throw-stick-ring3', ThrowOutcomeKind.stuck),
    ('throw-bounce-out', ThrowOutcomeKind.bounceOut),
    ('retrieve-knives', ThrowOutcomeKind.boardVisit),
  ];

  group('classifies each rendered sequence', () {
    for (final (name, expected) in cases) {
      test('$name → ${expected.name}', () {
        final f = Fixture(name);
        final episode = f.run().single;
        final outcome = classifyThrow(episode, f.calibration);
        expect(outcome.kind, expected, reason: '$outcome; $episode');

        if (expected == ThrowOutcomeKind.stuck) {
          // The new shape covers the knife's true entry point (in the 320 ×
          // 180 frame: half the sequence's 640 × 360 frame pixel).
          final knives = (f.truth['stuckKnivesAfter'] as List).cast<Map<String, dynamic>>();
          final entry = (knives.last['entryPixelFrame'] as List).cast<num>();
          final ex = entry[0] / 2, ey = entry[1] / 2;
          final o = outcome.object!;
          final near = o.pixels.any((i) => math.pow(i % o.imageWidth - ex, 2) + math.pow(i ~/ o.imageWidth - ey, 2) <= 9);
          expect(near, isTrue, reason: 'no new-object pixel within 3 px of the entry ($ex, $ey); centroid ${o.centroid}');
        }
      });
    }
  });

  group('without a before/after difference', () {
    final f = Fixture('throw-stick-ring4');
    final still = f.frames.first;

    MotionEpisode episode(LumaImage after, {double peak = 0.01, bool blocked = false, bool newScene = false}) =>
        MotionEpisode(
          startFrame: 0,
          settledFrame: 10,
          start: Duration.zero,
          settled: const Duration(seconds: 1),
          peakChange: peak,
          changeFromBefore: 0,
          wasBlocked: blocked,
          acceptedNewScene: newScene,
          before: still,
          after: after,
          threshold: 12,
        );

    test('noise alone is a bounce-out, not a stick', () {
      final random = math.Random(9);
      final noisy = LumaImage(still.width, still.height, Uint8List.fromList([
        for (final v in still.pixels)
          (v + (math.sqrt(-2 * math.log(1 - random.nextDouble())) * math.cos(2 * math.pi * random.nextDouble()) * 4))
              .round()
              .clamp(0, 255),
      ]));
      expect(classifyThrow(episode(noisy), f.calibration).kind, ThrowOutcomeKind.bounceOut);
    });

    test('someone blocking the board is a board visit', () {
      expect(classifyThrow(episode(still, blocked: true), f.calibration).kind, ThrowOutcomeKind.boardVisit);
    });

    test('a big change at once is a board visit', () {
      expect(classifyThrow(episode(still, peak: 0.2), f.calibration).kind, ThrowOutcomeKind.boardVisit);
    });

    test('an accepted new scene is reported as such', () {
      expect(classifyThrow(episode(still, newScene: true), f.calibration).kind, ThrowOutcomeKind.sceneChanged);
    });

    test('a new shape away from the target is not a stick', () {
      // A bright blob in the image corner, far outside the board.
      final after = LumaImage(still.width, still.height, Uint8List.fromList(still.pixels));
      for (var y = 2; y < 12; y++) {
        for (var x = 2; x < 12; x++) {
          after.pixels[y * still.width + x] = 255 - after.pixels[y * still.width + x];
        }
      }
      expect(classifyThrow(episode(after), f.calibration).kind, ThrowOutcomeKind.bounceOut);
    });
  });
}
