import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/board_shape.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/luma_image.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/target_locator.dart';

const boundaries = [0.2, 0.4, 0.6, 0.8];

/// A rendered sequence (tool/render_throw_sequences.dart), cut down to
/// 320 × 180 greyscale frames, with its answers.
class Fixture {
  Fixture(this.name) {
    final dir = 'test/fixtures/sequences/$name';
    truth = jsonDecode(File('$dir/truth.json').readAsStringSync()) as Map<String, dynamic>;
    phases = (truth['phases'] as List).cast<String>();
    frames = [
      for (var i = 0; i < phases.length; i++)
        LumaImage.fromRgb(decodeToRgb(File('$dir/frame-${i.toString().padLeft(3, '0')}.jpg').readAsBytesSync())!),
    ];
    final before = decodeToRgb(File('$dir/before.jpg').readAsBytesSync())!;
    final found = buildTargetLocator(boundaries).locate(before) as TargetFound;
    calibration = TargetCalibration(
      imageWidth: before.width,
      imageHeight: before.height,
      boundaries: found.boundaries,
      outer: found.outer,
    );
    region = WatchRegion.fromCalibration(calibration);
  }

  final String name;
  late final Map<String, dynamic> truth;
  late final List<String> phases;
  late final List<LumaImage> frames;
  late final TargetCalibration calibration;
  late final WatchRegion region;

  int get fps => truth['fps'] as int;
  int get firstMoving => phases.indexWhere((p) => p != 'settled');
  int get lastMoving => phases.lastIndexWhere((p) => p != 'settled');

  List<MotionEpisode> run({List<LumaImage>? override}) {
    final detector = MotionDetector(region);
    final episodes = <MotionEpisode>[];
    final input = override ?? frames;
    for (var i = 0; i < input.length; i++) {
      final update = detector.add(input[i], Duration(microseconds: (i * 1e6 / fps).round()));
      if (update.finished case final e?) episodes.add(e);
    }
    return episodes;
  }
}

void main() {
  final fixtures = {
    for (final name in ['throw-stick-ring4', 'throw-stick-ring3', 'throw-bounce-out', 'retrieve-knives'])
      name: Fixture(name),
  };

  group('one episode per rendered sequence, in the right place', () {
    for (final f in fixtures.values) {
      test(f.name, () {
        final episodes = f.run();
        expect(episodes, hasLength(1), reason: '$episodes');
        final e = episodes.single;
        // Not before anything happens, and not after it has all stopped.
        expect(e.startFrame, greaterThanOrEqualTo(f.firstMoving), reason: '$e; truth moving ${f.firstMoving}–${f.lastMoving}');
        expect(e.startFrame, lessThanOrEqualTo(f.lastMoving), reason: '$e');
        // Settles soon after the last moving frame (within the settle time +
        // 3 frames). The answers' phases describe the whole scene, not just
        // the watched region: the bounced knife keeps "moving" after falling
        // out of view, and the retrieving thrower after walking out of the
        // board's region. There, settling earlier is right, but never before
        // the knives are pulled (retrieval) or a settle time before the end.
        final settleFrames = (0.3 * f.fps).ceil();
        final event = f.truth['event'] as Map<String, dynamic>;
        final earliest = switch (event['type']) {
          'bounceOut' => f.lastMoving - settleFrames,
          'retrieval' => ((event['knivesPulledSeconds'] as num) * f.fps).ceil() + settleFrames,
          _ => f.lastMoving + 1,
        };
        expect(e.settledFrame, greaterThanOrEqualTo(earliest), reason: '$e');
        expect(e.settledFrame - f.lastMoving, lessThanOrEqualTo(settleFrames + 3), reason: '$e');
        expect(e.acceptedNewScene, isFalse, reason: '$e');
      });
    }
  });

  group('impact (Quick draw times throws by it)', () {
    /// A 100 × 100 grey picture, with a bright [w] × [h] block at ([x], [y]).
    LumaImage frame({int x = 0, int y = 0, int w = 0, int h = 0}) {
      final pixels = Uint8List(100 * 100)..fillRange(0, 100 * 100, 100);
      for (var r = y; r < y + h; r++) {
        pixels.fillRange(r * 100 + x, r * 100 + x + w, 220);
      }
      return LumaImage(100, 100, pixels);
    }

    // The whole picture watched; the target a circle of radius 30 in the middle.
    const region = WatchRegion(0, 0, 1, 1, target: EllipseShape(Ellipse(cx: 0.5, cy: 0.5, semiMajor: 0.3, semiMinor: 0.3, angle: 0)));

    /// Still frames, then [moving], then still again until it settles.
    MotionEpisode run(List<LumaImage> moving) {
      final detector = MotionDetector(region);
      final frames = [for (var i = 0; i < 10; i++) frame(), ...moving, for (var i = 0; i < 10; i++) frame()];
      for (var i = 0; i < frames.length; i++) {
        final e = detector.add(frames[i], Duration(milliseconds: i * 100)).finished;
        if (e != null) return e;
      }
      fail('never settled');
    }

    test('is the frame with the largest moving shape on the target, not where motion began', () {
      final e = run([
        frame(x: 2, y: 2, w: 3, h: 10), // 10: off the target (a knife flying in)
        frame(x: 45, y: 40, w: 3, h: 10), // 11: on it, small
        frame(x: 45, y: 40, w: 6, h: 20), // 12: on it, largest (the hit)
        frame(x: 45, y: 40, w: 3, h: 10), // 13: settling back
      ]);
      expect((e.startFrame, e.impactFrame), (10, 12));
      expect(e.impact, const Duration(milliseconds: 1200));
    });

    test('is null when nothing moved on the target', () {
      final e = run([frame(x: 2, y: 2, w: 3, h: 10), frame(x: 2, y: 60, w: 3, h: 10)]);
      expect(e.impactFrame, isNull);
    });
  });

  test('a person at the board changes far more of the region than a throw', () {
    final person = fixtures['retrieve-knives']!.run().single.peakChange;
    for (final name in ['throw-stick-ring4', 'throw-stick-ring3', 'throw-bounce-out']) {
      final throwPeak = fixtures[name]!.run().single.peakChange;
      expect(person, greaterThan(throwPeak * 5), reason: '$name: throw ${throwPeak * 100}%, person ${person * 100}%');
    }
  });

  test('camera noise alone never starts an episode (noisier than the renders)', () {
    final still = fixtures['throw-stick-ring4']!.frames.first;
    final random = math.Random(5);
    final noisy = [
      for (var i = 0; i < 60; i++)
        LumaImage(still.width, still.height, Uint8List.fromList([
          for (final v in still.pixels)
            (v + (math.sqrt(-2 * math.log(1 - random.nextDouble())) * math.cos(2 * math.pi * random.nextDouble()) * 4))
                .round()
                .clamp(0, 255),
        ])),
    ];
    expect(fixtures['throw-stick-ring4']!.run(override: noisy), isEmpty);
  });

  test('a slow brightness drift (a cloud) never starts an episode', () {
    final still = fixtures['throw-stick-ring4']!.frames.first;
    final drift = [
      for (var i = 0; i < 45; i++)
        LumaImage(still.width, still.height,
            Uint8List.fromList([for (final v in still.pixels) (v * (1 - 0.004 * i)).round().clamp(0, 255)])),
    ];
    expect(fixtures['throw-stick-ring4']!.run(override: drift), isEmpty);
  });

  test('motion off the target (people at the edge of the picture) is not counted as on it', () {
    final f = fixtures['throw-stick-ring4']!;
    final still = f.frames.first;
    // A blob in a corner of the watched region, outside the target.
    final x0 = (f.region.left * still.width).ceil() + 1, y0 = (f.region.top * still.height).ceil() + 1;
    final flicker = LumaImage(still.width, still.height, Uint8List.fromList(still.pixels));
    for (var y = y0; y < y0 + 5; y++) {
      for (var x = x0; x < x0 + 5; x++) {
        flicker.pixels[y * still.width + x] = 255 - flicker.pixels[y * still.width + x];
      }
    }
    final episodes = f.run(override: [for (var i = 0; i < 30; i++) i == 10 ? flicker : still]);
    expect(episodes, hasLength(1));
    expect(episodes.single.peakShape, 0);
    expect(episodes.single.peakArea, greaterThan(0));
  });

  group('compressed video (Live test recordings)', () {
    // A video encoder re-encodes the whole picture about once a second: every
    // pixel jumps by a few levels at once (here 15, with ±5 of grain).
    LumaImage jumped(LumaImage image, int seed) {
      final random = math.Random(seed);
      return LumaImage(image.width, image.height,
          Uint8List.fromList([for (final v in image.pixels) (v + 15 + random.nextInt(11) - 5).clamp(0, 255)]));
    }

    test('a whole-picture jump is not motion', () {
      final still = fixtures['throw-stick-ring4']!.frames.first;
      final frames = [for (var i = 0; i < 20; i++) i < 10 ? still : jumped(still, i)];
      expect(fixtures['throw-stick-ring4']!.run(override: frames), isEmpty);
    });

    test('a throw is still seen when the picture jumps during it', () {
      final f = fixtures['throw-stick-ring4']!;
      final frames = [
        for (var i = 0; i < f.frames.length; i++) i < f.firstMoving ? f.frames[i] : jumped(f.frames[i], i),
      ];
      expect(f.run(override: frames), hasLength(1));
    });
  });

  // Score corrections story, Task 2: after a pause, watching starts afresh.
  test('restart drops an episode under way: the still frames after it finish nothing', () {
    final f = Fixture('throw-stick-ring4');
    final detector = MotionDetector(f.region);
    var i = 0;
    for (; detector.state != WatchState.motion; i++) {
      detector.add(f.frames[i], Duration(microseconds: (i * 1e6 / f.fps).round()));
    }
    detector.restart();
    expect(detector.state, WatchState.watching);
    // The last frame again and again, for a second: without the restart it
    // would settle into an episode.
    final last = f.frames[f.frames.length - 1];
    for (var j = 0; j < f.fps; j++, i++) {
      final update = detector.add(last, Duration(microseconds: (i * 1e6 / f.fps).round()));
      expect(update.finished, isNull, reason: 'frame $j after the restart');
    }
  });
}
