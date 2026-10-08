import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/target_calibration.dart';

/// A target seen from the side: long axis vertical, rings slightly off-centre
/// from each other as perspective makes them.
TargetCalibration sample() => TargetCalibration(
      imageWidth: 1280,
      imageHeight: 720,
      boundaries: {
        0.2: Ellipse(cx: 641, cy: 360, semiMajor: 40, semiMinor: 28, angle: math.pi / 2),
        0.8: Ellipse(cx: 639, cy: 360, semiMajor: 160, semiMinor: 112, angle: math.pi / 2),
      },
      outer: Ellipse(cx: 640, cy: 360, semiMajor: 200, semiMinor: 140, angle: math.pi / 2),
    );

void main() {
  test('handles sit on the ends of the outer ellipse axes', () {
    final c = sample();
    expect(c.majorHandle.x, closeTo(640, 1e-9));
    expect(c.majorHandle.y, closeTo(560, 1e-9));
    expect(c.minorHandle.x, closeTo(500, 1e-9));
    expect(c.minorHandle.y, closeTo(360, 1e-9));
  });

  test('moving shifts every ring and keeps their sizes', () {
    final m = sample().moved(10, -5);
    expect(m.outer.cx, 650);
    expect(m.outer.cy, 355);
    expect(m.boundaries[0.2]!.cx, 651);
    expect(m.boundaries[0.8]!.semiMajor, 160);
  });

  test('dragging the long-axis handle further out stretches every ring in proportion', () {
    final c = sample().withMajorHandleAt(const Point2(640, 580));
    expect(c.outer.semiMajor, closeTo(220, 1e-6));
    expect(c.outer.semiMinor, closeTo(140, 1e-6));
    expect(c.boundaries[0.8]!.semiMajor, closeTo(176, 1e-6));
    expect(c.boundaries[0.2]!.semiMajor, closeTo(44, 1e-6));
    expect(c.majorHandle.y, closeTo(580, 1e-6));
  });

  test('dragging the long-axis handle sideways turns every ring', () {
    // From straight down (90°) to down-left at 45° from vertical.
    final to = Point2(640 - 200 * math.sin(math.pi / 4), 360 + 200 * math.cos(math.pi / 4));
    final c = sample().withMajorHandleAt(to);
    expect(c.outer.angle, closeTo(math.pi * 3 / 4, 1e-9));
    expect(c.boundaries[0.2]!.angle, closeTo(math.pi * 3 / 4, 1e-9));
    expect(c.majorHandle.x, closeTo(to.x, 1e-6));
    expect(c.majorHandle.y, closeTo(to.y, 1e-6));
    // Ring centres turn with it about the outer centre.
    final gap = c.boundaries[0.2]!.cx - c.outer.cx;
    expect(gap.abs(), lessThan(1.0));
  });

  test('dragging the short-axis handle stretches only the short axes', () {
    final c = sample().withMinorHandleAt(const Point2(480, 360));
    expect(c.outer.semiMinor, closeTo(160, 1e-6));
    expect(c.outer.semiMajor, closeTo(200, 1e-6));
    expect(c.boundaries[0.8]!.semiMinor, closeTo(128, 1e-6));
    expect(c.boundaries[0.8]!.semiMajor, closeTo(160, 1e-6));
  });

  test('the short-axis handle measures along the short axis only', () {
    final c = sample().withMinorHandleAt(const Point2(480, 300));
    expect(c.outer.semiMinor, closeTo(160, 1e-6));
  });

  test('a handle dragged onto the centre is ignored (no collapse)', () {
    final c = sample();
    expect(identical(c.withMajorHandleAt(const Point2(640, 360)), c), isTrue);
    expect(identical(c.withMinorHandleAt(const Point2(640, 360)), c), isTrue);
  });
}
