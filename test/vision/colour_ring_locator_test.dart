import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/colour_ring_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/synthetic_target.dart';
import 'package:thrower_app/vision/target_locator.dart';

const boundaries = [0.2, 0.4, 0.6, 0.8];

ColourRingLocator locator() => ColourRingLocator(boundaryRadii: boundaries);

double angleGap(double a, double b) {
  final d = (a - b).abs() % math.pi;
  return math.min(d, math.pi - d);
}

/// Checks [actual] is within [tolerance] (as a fraction of the expected
/// semi-major axis) of [expected].
void expectNear(Ellipse actual, Ellipse expected, {double tolerance = 0.03}) {
  final tol = expected.semiMajor * tolerance;
  expect(actual.cx, closeTo(expected.cx, tol), reason: 'centre x: $actual vs $expected');
  expect(actual.cy, closeTo(expected.cy, tol), reason: 'centre y: $actual vs $expected');
  expect(actual.semiMajor, closeTo(expected.semiMajor, tol), reason: 'semi-major: $actual vs $expected');
  expect(actual.semiMinor, closeTo(expected.semiMinor, tol), reason: 'semi-minor: $actual vs $expected');
  // A turned ellipse's edge moves by up to (a − b)·sin(Δangle), so a nearly
  // round ellipse's angle hardly matters: check that movement, not the angle.
  final edgeShift = (expected.semiMajor - expected.semiMinor) * math.sin(angleGap(actual.angle, expected.angle));
  expect(edgeShift, lessThan(tol), reason: 'angle: $actual vs $expected');
}

RgbImage loadFixture(String name) => decodeToRgb(File('test/fixtures/targets/$name').readAsBytesSync())!;

void main() {
  group('finds the rings on a synthetic target', () {
    final scenes = <(String, SyntheticTarget)>[
      ('straight on', SyntheticTarget()),
      ('40° from the side', SyntheticTarget(viewAngleDegrees: 40)),
      ('55° from the side, tilted 20°', SyntheticTarget(viewAngleDegrees: 55, rotationDegrees: 20)),
      (
        'with three knife handles',
        SyntheticTarget(viewAngleDegrees: 30, knives: [(0.1, 0.05), (-0.5, -0.3), (0.45, 0.5)]),
      ),
      ('off-centre in a large frame', SyntheticTarget(width: 1600, height: 1200, radiusPx: 300)),
      (
        '55° from the side, tilted, with knife handles',
        SyntheticTarget(viewAngleDegrees: 55, rotationDegrees: 20, knives: [(0.1, 0.05), (-0.5, -0.3), (0.45, 0.5)]),
      ),
      // Rings can be any two colours, not just red paint on wood.
      (
        'black and white rings on a grey wall',
        SyntheticTarget(colourA: (30, 30, 35), colourB: (235, 235, 230), background: (150, 150, 150)),
      ),
      (
        'blue and yellow rings, 45° from the side',
        SyntheticTarget(viewAngleDegrees: 45, colourA: (30, 60, 170), colourB: (240, 210, 50)),
      ),
      (
        'green bull on white, green background, with knife handles',
        SyntheticTarget(
          viewAngleDegrees: 30,
          colourA: (40, 140, 60),
          colourB: (240, 240, 235),
          background: (70, 130, 60),
          knives: [(0.1, 0.05), (-0.5, -0.3)],
        ),
      ),
      (
        'wood bull with red rings (colours swapped)',
        SyntheticTarget(viewAngleDegrees: 35, colourA: (227, 201, 160), colourB: (198, 40, 40)),
      ),
    ];
    for (final (name, scene) in scenes) {
      test(name, () {
        final result = locator().locate(scene.render());
        expect(result, isA<TargetFound>(), reason: result is TargetNotFound ? result.reason : '');
        final found = result as TargetFound;
        for (final r in boundaries) {
          expectNear(found.boundaries[r]!, scene.expectedEllipse(r));
        }
        expectNear(found.outer, scene.expectedEllipse(1.0));
        expect(found.confidence, greaterThan(0.7));
      });
    }
  });

  test('reports not found on an image with no target', () {
    final grass = RgbImage.blank(400, 300);
    for (var y = 0; y < 300; y++) {
      for (var x = 0; x < 400; x++) {
        grass.setPixel(x, y, 70, 130, 60);
      }
    }
    expect(locator().locate(grass), isA<TargetNotFound>());
  });

  test('finds the rings on the reference photo (red/wood log, two knives)', () {
    final result = locator().locate(loadFixture('target-example.jpg'));
    expect(result, isA<TargetFound>(), reason: result is TargetNotFound ? result.reason : '');
    final found = result as TargetFound;
    // Hand-measured on the 600 × 800 fixture: the bull's centre and the
    // red ring edge at normalised radius 0.8.
    final edge = found.boundaries[0.8]!;
    expect(edge.cx, closeTo(_photoCentre.x, 12));
    expect(edge.cy, closeTo(_photoCentre.y, 12));
    expect(edge.semiMajor, closeTo(_photoEdgeSemiMajor, 15));
    expect(found.confidence, greaterThan(0.6));
  });

  test('finds the rings on the reference photo recoloured blue/pale blue (red and blue swapped)', () {
    final photo = loadFixture('target-example.jpg');
    final swapped = RgbImage.blank(photo.width, photo.height);
    for (var y = 0; y < photo.height; y++) {
      for (var x = 0; x < photo.width; x++) {
        swapped.setPixel(x, y, photo.blue(x, y), photo.green(x, y), photo.red(x, y));
      }
    }
    final result = locator().locate(swapped);
    expect(result, isA<TargetFound>(), reason: result is TargetNotFound ? result.reason : '');
    final edge = (result as TargetFound).boundaries[0.8]!;
    expect(edge.cx, closeTo(_photoCentre.x, 12));
    expect(edge.cy, closeTo(_photoCentre.y, 12));
    expect(edge.semiMajor, closeTo(_photoEdgeSemiMajor, 15));
  });
}

// From the overlay produced by tool/locate_target.dart, checked by eye against
// the painted edges (Task 1 record in the target calibration story).
const _photoCentre = Point2(293, 317);
const _photoEdgeSemiMajor = 157.0;
