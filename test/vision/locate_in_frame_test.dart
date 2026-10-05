import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/camera_frame.dart';
import 'package:thrower_app/vision/locate_in_frame.dart';
import 'package:thrower_app/vision/synthetic_target.dart';
import 'package:thrower_app/vision/target_locator.dart';

import 'frame_to_rgb_test.dart' show bgraFrame, rotatedAnticlockwise, yuvFrame;

void main() {
  const boundaries = [0.2, 0.4, 0.6, 0.8];
  // Upright portrait scene, as the user sees it on screen; within the 600 px
  // working size so it isn't downscaled and the expected ellipses apply as-is.
  final scene = SyntheticTarget(width: 450, height: 600, radiusPx: 170, viewAngleDegrees: 35);
  final upright = scene.render();
  final sensorView = rotatedAnticlockwise(upright);

  final formats = <(String, CameraFrame Function())>[
    ('BGRA (iOS)', () => bgraFrame(sensorView)),
    ('YUV420 (Android)', () => yuvFrame(sensorView)),
  ];
  for (final (name, makeFrame) in formats) {
    test('finds the target upright in a sideways $name frame', () {
      final found = locateInFrame((makeFrame(), 90, boundaries));
      expect(found.result, isA<TargetFound>(),
          reason: found.result is TargetNotFound ? (found.result as TargetNotFound).reason : '');
      expect(found.imageWidth, 450);
      expect(found.imageHeight, 600);
      final edge = (found.result as TargetFound).boundaries[0.8]!;
      final expected = scene.expectedEllipse(0.8);
      expect(edge.cx, closeTo(expected.cx, 5));
      expect(edge.cy, closeTo(expected.cy, 5));
      expect(edge.semiMajor, closeTo(expected.semiMajor, 5));
      expect(edge.semiMinor, closeTo(expected.semiMinor, 5));
    });
  }

  test('reports an unsupported format instead of failing', () {
    const frame = CameraFrame(width: 4, height: 4, format: FrameFormat.nv21, planes: [], timestamp: Duration.zero);
    final found = locateInFrame((frame, 0, boundaries));
    expect(found.result, isA<TargetNotFound>());
  });
}
