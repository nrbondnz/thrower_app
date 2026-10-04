import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/ellipse.dart';

/// Smallest difference between two axis angles (an axis has no sign).
double angleGap(double a, double b) {
  final d = (a - b).abs() % math.pi;
  return math.min(d, math.pi - d);
}

void expectEllipse(Ellipse? actual, Ellipse expected, {double tol = 0.5}) {
  expect(actual, isNotNull);
  final e = actual!;
  expect(e.cx, closeTo(expected.cx, tol), reason: 'centre x of $e');
  expect(e.cy, closeTo(expected.cy, tol), reason: 'centre y of $e');
  expect(e.semiMajor, closeTo(expected.semiMajor, tol), reason: 'semi-major of $e');
  expect(e.semiMinor, closeTo(expected.semiMinor, tol), reason: 'semi-minor of $e');
  if (expected.semiMajor - expected.semiMinor > 1) {
    expect(angleGap(e.angle, expected.angle), lessThan(0.02), reason: 'angle of $e');
  }
}

void main() {
  const shapes = <(String, Ellipse)>[
    ('circle', Ellipse(cx: 100, cy: 80, semiMajor: 50, semiMinor: 50, angle: 0)),
    ('horizontal', Ellipse(cx: 300, cy: 200, semiMajor: 120, semiMinor: 60, angle: 0)),
    ('vertical', Ellipse(cx: 300, cy: 200, semiMajor: 120, semiMinor: 60, angle: math.pi / 2)),
    ('tilted 30°', Ellipse(cx: -40, cy: 500, semiMajor: 90, semiMinor: 30, angle: math.pi / 6)),
  ];

  group('fitEllipse recovers an ellipse from points on it', () {
    for (final (name, shape) in shapes) {
      test(name, () {
        final points = [for (var i = 0; i < 40; i++) shape.pointAt(2 * math.pi * i / 40)];
        expectEllipse(fitEllipse(points), shape);
      });
    }
  });

  test('fitEllipse works from part of the outline', () {
    final shape = shapes[3].$2;
    final points = [for (var i = 0; i < 20; i++) shape.pointAt(math.pi * i / 20)];
    expectEllipse(fitEllipse(points), shape);
  });

  test('fitEllipse needs at least 6 points', () {
    final shape = shapes[0].$2;
    expect(fitEllipse([for (var i = 0; i < 5; i++) shape.pointAt(i.toDouble())]), isNull);
  });

  test('fitEllipse rejects points on a line', () {
    expect(fitEllipse([for (var i = 0; i < 10; i++) Point2(i.toDouble(), 2.0 * i)]), isNull);
  });

  test('fitEllipseRansac ignores a quarter of points that are outliers', () {
    final shape = shapes[1].$2;
    final random = math.Random(3);
    final points = [
      for (var i = 0; i < 60; i++) shape.pointAt(2 * math.pi * i / 60),
      for (var i = 0; i < 20; i++) Point2(200 + random.nextDouble() * 200, 100 + random.nextDouble() * 200),
    ];
    final result = fitEllipseRansac(points);
    expectEllipse(result?.ellipse, shape);
    expect(result!.inliers.length, greaterThanOrEqualTo(60));
  });

  test('normalisedRadius is 1 on the ellipse and 0.5 halfway to the centre', () {
    final shape = shapes[3].$2;
    final p = shape.pointAt(1);
    expect(shape.normalisedRadius(p), closeTo(1, 1e-9));
    final half = Point2((p.x + shape.cx) / 2, (p.y + shape.cy) / 2);
    expect(shape.normalisedRadius(half), closeTo(0.5, 1e-9));
  });
}
