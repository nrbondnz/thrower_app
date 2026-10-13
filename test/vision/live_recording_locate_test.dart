import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/frame_pack.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/target_locator.dart';

/// Where the rings really are on the two Live test boards: the centre and the
/// mean radius of each boundary (bull, rings 4, 3, 2) in the 322 × 322 frames
/// cut from the original video, measured from the colour averaged around the
/// centre on the still at its start (2026-10-12; the centre is where the
/// edges are sharpest). They match the 140 px copy's (2026-10-11) × 2.3.
const measured = {
  'Target 1': ((155.8, 160.1), [19.5, 37.0, 57.5, 74.0]),
  'Target 2': ((166.0, 158.5), [20.0, 37.5, 58.0, 74.0]),
};

const boundaryRadii = [0.2, 0.4, 0.6, 0.8];

/// Null if [result] matches the measured rings within [tolerance] px (centre
/// and each boundary's mean radius), otherwise what's wrong. 3 px is about
/// 4% of the outer boundary.
String? mismatch(TargetLocateResult result, String board, {double tolerance = 3}) {
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

      test('the first frame (where the Live test calibrates) is found, every ring within 3 px', () {
        expect(mismatch(locator.locate(decodeToRgb(pack.jpeg(0))!), recording.name), isNull);
      });

      // Throughout the video the board is sometimes blocked by people, and
      // knives crowd the bull. A floor on right answers and a ceiling on wrong
      // ones (worse than none: every throw would be mis-scored) guard against
      // regressions. Results 2026-10-12, every 10 s (19 frames), on the
      // full-resolution recordings: Target 1: 17 right, 1 wrong; Target 2:
      // 10 right, 4 wrong. All but one wrong one are near misses (one
      // boundary 3–4 px out; board 2 at 30 s has its 0.6 boundary 8 px out).
      // The rest are "not found", which the person calibrating sees and
      // retries. (On the 140 px copy: 13 / 1 and 8 / 2.)
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
        expect(right, greaterThanOrEqualTo(recording.name == 'Target 1' ? 17 : 10), reason: report.join('\n'));
        expect(wrong, lessThanOrEqualTo(recording.name == 'Target 1' ? 1 : 4), reason: report.join('\n'));
      });
    });
  }
}
