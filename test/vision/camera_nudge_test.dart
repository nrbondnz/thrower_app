import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/luma_image.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/target_locator.dart';
import 'package:thrower_app/vision/throw_classifier.dart';

import 'motion_detector_test.dart' show Fixture;

/// Reads a binary PGM (as saved by the debug watch log).
LumaImage loadPgm(String path) {
  final bytes = File(path).readAsBytesSync();
  var i = 0, fields = <int>[];
  while (fields.length < 3) {
    while (bytes[i] == 0x0a || bytes[i] == 0x20 || bytes[i] == 0x0d) {
      i++;
    }
    if (bytes[i] == 0x50) {
      i += 2; // "P5"
      continue;
    }
    var n = 0;
    while (bytes[i] >= 0x30 && bytes[i] <= 0x39) {
      n = n * 10 + bytes[i++] - 0x30;
    }
    fields.add(n);
  }
  i++; // The single whitespace after the max value.
  final (w, h) = (fields[0], fields[1]);
  return LumaImage(w, h, Uint8List.fromList(bytes.sublist(i, i + w * h)));
}

/// [img] moved by ([dx], [dy]) pixels, edges repeated (a camera nudge).
LumaImage shifted(LumaImage img, int dx, int dy) {
  final out = Uint8List(img.width * img.height);
  for (var y = 0; y < img.height; y++) {
    for (var x = 0; x < img.width; x++) {
      final sx = (x - dx).clamp(0, img.width - 1), sy = (y - dy).clamp(0, img.height - 1);
      out[y * img.width + x] = img.pixels[sy * img.width + sx];
    }
  }
  return LumaImage(img.width, img.height, out);
}

List<MotionEpisode> run(MotionDetector d, List<LumaImage> frames) {
  final episodes = <MotionEpisode>[];
  final states = <WatchState>{};
  for (var i = 0; i < frames.length; i++) {
    final u = d.add(frames[i], Duration(milliseconds: i * 67));
    states.add(u.state);
    if (u.finished case final e?) episodes.add(e);
  }
  expect(states, isNot(contains(WatchState.blocked)), reason: 'a nudge must not look like someone at the board');
  return episodes;
}

void main() {
  group("Nigel's real frames: the phone, propped on a sofa arm, nudged by ~1 px (2026-10-09)", () {
    // Before the fix this read as 9.1% different: "someone at the board", then
    // "the view changed".
    final before = loadPgm('test/fixtures/real/nudge-before.pgm');
    final after = loadPgm('test/fixtures/real/nudge-after.pgm');
    final grey = RgbImage.blank(before.width, before.height);
    for (var i = 0; i < before.pixels.length; i++) {
      final v = before.pixels[i];
      grey.setPixel(i % before.width, i ~/ before.width, v, v, v);
    }
    final found = buildTargetLocator(const [0.2, 0.4, 0.6, 0.8]).locate(grey) as TargetFound;
    final calibration = TargetCalibration(
      imageWidth: before.width,
      imageHeight: before.height,
      boundaries: found.boundaries,
      outer: found.outer,
    );

    test('is never "someone at the board" or "the view changed"', () {
      final d = MotionDetector(WatchRegion.fromCalibration(calibration));
      final episodes = run(d, [for (var i = 0; i < 8; i++) before, for (var i = 0; i < 15; i++) after]);
      for (final e in episodes) {
        expect(e.acceptedNewScene, isFalse);
        expect(e.changeFromBefore, lessThan(0.08), reason: '$e');
      }
    });

    test('leaves no false new knife', () {
      final episode = MotionEpisode(
        startFrame: 0,
        settledFrame: 10,
        start: Duration.zero,
        settled: const Duration(seconds: 1),
        peakChange: 0.01,
        changeFromBefore: 0.01,
        before: before,
        after: after,
        threshold: 12,
      );
      expect(classifyThrow(episode, calibration).kind, ThrowOutcomeKind.bounceOut);
    });
  });

  group('a still board with the camera jumping between frames starts no episode (no false bounce-outs)', () {
    final f = Fixture('throw-stick-ring4');
    final still = f.frames.first;
    for (final (dx, dy) in [(1, 0), (0, 1), (2, 1), (-2, -2), (3, 0)]) {
      test('jump of ($dx, $dy) px', () {
        final d = MotionDetector(f.region);
        final frames = [for (var i = 0; i < 8; i++) still, for (var i = 0; i < 12; i++) shifted(still, dx, dy)];
        expect(run(d, frames), isEmpty);
      });
    }
  });

  test('a knife sticking just after a nudge is still found (rendered ring-4 throw, camera moved 1 px)', () {
    final f = Fixture('throw-stick-ring4');
    final frames = [for (var i = 0; i < f.frames.length; i++) i < 12 ? f.frames[i] : shifted(f.frames[i], 1, 1)];
    final episodes = run(MotionDetector(f.region), frames);
    expect(episodes, isNotEmpty);
    expect(classifyThrow(episodes.last, f.calibration).kind, ThrowOutcomeKind.stuck);
  });
}
