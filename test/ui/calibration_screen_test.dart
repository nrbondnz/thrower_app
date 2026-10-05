import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/ui/calibration_screen.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/locate_in_frame.dart';
import 'package:thrower_app/vision/target_locator.dart';

void main() {
  const ring = Ellipse(cx: 1, cy: 1, semiMajor: 1, semiMinor: 1, angle: 0);

  test('prompts before the first search', () {
    expect(calibrationStatus(null, searching: false), startsWith('Point the phone'));
  });

  test('shows progress while searching', () {
    expect(calibrationStatus(null, searching: true), 'Looking for the target…');
  });

  test('reports confidence and time when found', () {
    final found = FrameLocateResult(
      TargetFound(boundaries: {0.8: ring}, outer: ring, confidence: 0.853, boundaryPoints: {}),
      600,
      800,
    );
    expect(calibrationStatus(found, searching: false, millis: 420), 'Target found: confidence 85% (420 ms)');
  });

  test('reports the reason when not found', () {
    const found = FrameLocateResult(TargetNotFound('No large red area found'), 600, 800);
    expect(calibrationStatus(found, searching: false, millis: 300), 'Target not found: No large red area found (300 ms)');
  });
}
