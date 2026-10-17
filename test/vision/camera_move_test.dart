import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:thrower_app/camera/frame_pack.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/vision/camera_move.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/luma_image.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/target_calibration.dart';

import 'camera_nudge_test.dart' show loadPgm, shifted;
import 'motion_detector_test.dart' show Fixture;

/// Score corrections story, Task 3: after someone at the phone changes a
/// score, did the phone move? The cases [phoneMovedShift] was set from.
LumaImage lumaOf(FramePack pack, int i) {
  final g = img.grayscale(img.decodeJpg(pack.jpeg(i))!);
  return LumaImage(g.width, g.height, g.getBytes(order: img.ChannelOrder.red));
}

void main() {
  final f = Fixture('throw-stick-ring4');
  final still = f.frames.first;

  test('the same picture has not moved', () {
    expect(cameraShift(still, still, f.region), 0);
  });

  group('the camera moved by (dx, dy) px on the rendered board', () {
    for (final (dx, dy, moved) in [(1, 0, false), (1, 1, false), (2, 0, true), (0, -2, true), (3, 1, true), (6, 0, true)]) {
      test('($dx, $dy): ${moved ? '' : 'not '}moved', () {
        expect(phoneMoved(still, shifted(still, dx, dy), f.region), moved,
            reason: 'shift ${cameraShift(still, shifted(still, dx, dy), f.region)}');
      });
    }
  });

  test('a shift beyond the search is still caught (as the most it looks for)', () {
    expect(cameraShift(still, shifted(still, 12, 0), f.region), 8);
  });

  group('new content without the camera moving is not a move', () {
    for (final name in ['throw-stick-ring4', 'throw-bounce-out', 'retrieve-knives']) {
      test('$name: first frame vs last', () {
        final s = Fixture(name);
        expect(phoneMoved(s.frames.first, s.frames.last, s.region), isFalse);
      });
    }
  });

  test("Nigel's sofa-arm nudge (~1.4 px, 2026-10-09) is not a move", () {
    final before = loadPgm('test/fixtures/real/nudge-before.pgm');
    final after = loadPgm('test/fixtures/real/nudge-after.pgm');
    final outer = Ellipse(cx: 60.6, cy: 54.4, semiMajor: 30.6, semiMinor: 25.1, angle: 71.6 * math.pi / 180);
    final region = WatchRegion.fromCalibration(TargetCalibration(
      imageWidth: before.width,
      imageHeight: before.height,
      boundaries: {for (final r in const [0.2, 0.4, 0.6, 0.8]) r: outer.scaled(r)},
      outer: outer,
    ));
    expect(cameraShift(before, after, region), closeTo(1.41, 0.01));
    expect(phoneMoved(before, after, region), isFalse);
  });

  test('the Live test footage, still for a second, has not moved (compression shifts it 1 px at most)', () {
    for (final rec in liveTestRecordings) {
      final pack = FramePack.parse(File(rec.asset).readAsBytesSync());
      final first = lumaOf(pack, 0);
      for (final i in [1, 5, 15, 30]) {
        expect(cameraShift(first, lumaOf(pack, i), const WatchRegion(0.2, 0.2, 0.8, 0.8)), lessThanOrEqualTo(1),
            reason: '${rec.name} frame $i');
      }
    }
  });
}
