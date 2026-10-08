import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
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
    region = WatchRegion.fromCalibration(TargetCalibration(
      imageWidth: before.width,
      imageHeight: before.height,
      boundaries: found.boundaries,
      outer: found.outer,
    ));
  }

  final String name;
  late final Map<String, dynamic> truth;
  late final List<String> phases;
  late final List<LumaImage> frames;
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
}
