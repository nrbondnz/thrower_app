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

  group('knives already in the board', () {
    final f = Fixture('throw-stick-ring4');
    final stuck = classifyThrow(f.run().single, f.calibration);
    final knife = stuck.object!;
    final empty = f.frames.first, withKnife = f.frames.last;

    MotionEpisode between(LumaImage before, LumaImage after, {bool blocked = false}) => MotionEpisode(
          startFrame: 0,
          settledFrame: 10,
          start: Duration.zero,
          settled: const Duration(seconds: 1),
          peakChange: 0.01,
          changeFromBefore: 0.007,
          wasBlocked: blocked,
          before: before,
          after: after,
          threshold: 12,
        );

    test('a known knife disappearing on its own is "fell out", not a new stick', () {
      final outcome = classifyThrow(between(withKnife, empty), f.calibration, knownKnives: [knife]);
      expect(outcome.kind, ThrowOutcomeKind.fellOut);
      expect(outcome.knownKnifeIndex, 0);
    });

    test('without knowing the knives, the same change looks like a stick (why tracking is needed)', () {
      expect(classifyThrow(between(withKnife, empty), f.calibration).kind, ThrowOutcomeKind.stuck);
    });

    group('someone at the board', () {
      test('placing a knife (or a pen) by hand is a stick', () {
        final outcome = classifyThrow(between(empty, withKnife, blocked: true), f.calibration);
        expect(outcome.kind, ThrowOutcomeKind.stuck, reason: '$outcome');
      });

      test('pulling out a knife the app knows is a board visit', () {
        final outcome = classifyThrow(between(withKnife, empty, blocked: true), f.calibration, knownKnives: [knife]);
        expect(outcome.kind, ThrowOutcomeKind.boardVisit);
      });

      test('pulling out a knife the app never saw is still a board visit (it disappeared, not appeared)', () {
        expect(classifyThrow(between(withKnife, empty, blocked: true), f.calibration).kind, ThrowOutcomeKind.boardVisit);
      });

      test('putting a knife in while taking the known one out is a board visit (collecting)', () {
        // The ring-3 sequence ends with the ring-4 and ring-3 knives; wipe the
        // ring-4 one (and 2 px around it) back to the empty board.
        final both = Fixture('throw-stick-ring3').frames.last;
        final onlyRing3 = LumaImage(both.width, both.height, Uint8List.fromList(both.pixels));
        for (final i in knife.pixels) {
          final x = i % both.width, y = i ~/ both.width;
          for (var dy = -2; dy <= 2; dy++) {
            for (var dx = -2; dx <= 2; dx++) {
              final j = (y + dy) * both.width + x + dx;
              onlyRing3.pixels[j] = empty.pixels[j];
            }
          }
        }
        final outcome = classifyThrow(between(withKnife, onlyRing3, blocked: true), f.calibration, knownKnives: [knife]);
        expect(outcome.kind, ThrowOutcomeKind.boardVisit, reason: '$outcome');
      });
    });

    test('a new knife elsewhere is still a stick when another knife is known', () {
      final f3 = Fixture('throw-stick-ring3');
      final outcome = classifyThrow(f3.run().single, f3.calibration, knownKnives: [knife]);
      expect(outcome.kind, ThrowOutcomeKind.stuck);
    });
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
