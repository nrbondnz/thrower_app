import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/frame_pack.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/target_locator.dart';

/// Where the rings really are on the two Live test boards: the centre and the
/// mean radius of each boundary (bull, rings 4, 3, 2) in the 140 × 140 frames,
/// measured from the colour averaged around the centre on the still at the
/// start of each video (2026-10-11).
const measured = {
  'Target 1': ((67.6, 69.8), [8.5, 16.5, 25.0, 32.5]),
  'Target 2': ((72.2, 69.0), [8.5, 16.5, 25.5, 32.5]),
};

const boundaryRadii = [0.2, 0.4, 0.6, 0.8];

/// Null if [result] matches the measured rings within [tolerance] px (centre
/// and each boundary's mean radius), otherwise what's wrong.
String? mismatch(TargetLocateResult result, String board, {double tolerance = 2.5}) {
  if (result is! TargetFound) return 'not found: ${(result as TargetNotFound).reason}';
  final ((cx, cy), radii) = measured[board]!;
  for (var i = 0; i < boundaryRadii.length; i++) {
    final e = result.boundaries[boundaryRadii[i]]!;
    final radius = (e.semiMajor + e.semiMinor) / 2;
    final off = math.sqrt(math.pow(e.cx - cx, 2) + math.pow(e.cy - cy, 2));
    if ((radius - radii[i]).abs() > tolerance || off > tolerance) {
      return 'boundary ${boundaryRadii[i]}: radius ${radius.toStringAsFixed(1)} (measured ${radii[i]}), '
          'centre ${off.toStringAsFixed(1)} px off';
    }
  }
  return null;
}

void main() {
  final locator = buildTargetLocator(boundaryRadii);

  for (final recording in liveTestRecordings) {
    group('${recording.name} (${recording.description})', () {
      final pack = FramePack.parse(File(recording.asset).readAsBytesSync());

      test('the first frame (where the Live test calibrates) is found, every ring within 2.5 px', () {
        expect(mismatch(locator.locate(decodeToRgb(pack.jpeg(0))!), recording.name), isNull);
      });

      // Throughout the video the board is often blocked or blurred by
      // compression, and knives crowd the bull. A floor on right answers and a
      // ceiling on wrong ones (worse than none: every throw would be mis-scored)
      // guard against regressions. Results 2026-10-11, every 10 s (19 frames):
      // Target 1: 13 right, 1 wrong; Target 2: 8 right, 2 wrong. The rest are
      // "not found", which the person calibrating sees and retries.
      test('every 10 s: mostly found right, rarely wrong', () {
        var right = 0, wrong = 0;
        final report = <String>[];
        for (var t = 0; t * 15 < pack.frameCount; t += 10) {
          final result = locator.locate(decodeToRgb(pack.jpeg(t * 15))!);
          final problem = mismatch(result, recording.name);
          if (result is TargetFound) {
            problem == null ? right++ : wrong++;
          }
          report.add('$t s: ${problem ?? 'right'}');
        }
        expect(right, greaterThanOrEqualTo(recording.name == 'Target 1' ? 13 : 8), reason: report.join('\n'));
        expect(wrong, lessThanOrEqualTo(2), reason: report.join('\n'));
      });
    });
  }
}
