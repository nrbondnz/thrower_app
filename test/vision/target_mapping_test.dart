import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/target_locator.dart';
import 'package:thrower_app/vision/target_mapping.dart';

const boundaries = [0.2, 0.4, 0.6, 0.8];

/// A hand-painted target seen from the side: concentric ellipses (long axis
/// vertical, 0.7 squash) with painted edges at 0.22 / 0.39 / 0.62 / 0.8 of a
/// 200 px outer radius, centred at (500, 400).
TargetCalibration painted() {
  Ellipse at(double r) => Ellipse(cx: 500, cy: 400, semiMajor: 200 * r, semiMinor: 140 * r, angle: math.pi / 2);
  return TargetCalibration(
    imageWidth: 1000,
    imageHeight: 800,
    boundaries: {0.2: at(0.22), 0.4: at(0.39), 0.6: at(0.62), 0.8: at(0.8)},
    outer: at(1.0),
  );
}

double radius(TargetPoint p) => math.sqrt(p.x * p.x + p.y * p.y);

/// The rendered board's painted edges (measured from the reference photo by
/// tool/render_camera_views.dart; `paintedRingRadii` in its truth.json).
const paintedEdges = [0.219, 0.395, 0.620, 0.8, 1.0];
const idealEdges = [0.2, 0.4, 0.6, 0.8, 1.0];

/// A radius on the painted board, as the equivalent radius on the ideal scale.
double idealEquivalent(double r) {
  if (r <= paintedEdges.first) return idealEdges.first * r / paintedEdges.first;
  for (var k = 0; k + 1 < paintedEdges.length; k++) {
    if (r <= paintedEdges[k + 1]) {
      final t = (r - paintedEdges[k]) / (paintedEdges[k + 1] - paintedEdges[k]);
      return idealEdges[k] + t * (idealEdges[k + 1] - idealEdges[k]);
    }
  }
  return 1 + (r - 1) * 0.2 / (1 - paintedEdges[3]);
}

void main() {
  group('TargetMapping on a hand-painted target', () {
    final mapping = TargetMapping(painted());

    test('a point on each painted edge gets exactly that edge\'s radius', () {
      final c = painted();
      for (final r in boundaries) {
        final e = c.boundaries[r]!;
        for (final t in [0.0, 1.0, 2.5, 4.0]) {
          expect(radius(mapping.toTarget(e.pointAt(t))), closeTo(r, 1e-9), reason: 'edge $r at t=$t');
        }
      }
      expect(radius(mapping.toTarget(c.outer.pointAt(1))), closeTo(1.0, 1e-9));
    });

    test('halfway between two painted edges is halfway between their radii', () {
      // Straight down from the centre (along the long axis): 0.39 → 0.62 of 200 px.
      final p = Point2(500, 400 + 200 * (0.39 + 0.62) / 2);
      expect(radius(mapping.toTarget(p)), closeTo(0.5, 1e-9));
    });

    test('inside the bull the radius grows in proportion', () {
      expect(radius(mapping.toTarget(const Point2(500, 400))), 0);
      final p = Point2(500, 400 + 200 * 0.11);
      expect(radius(mapping.toTarget(p)), closeTo(0.1, 1e-9));
    });

    test('beyond the outer edge it carries on at the outermost ring\'s rate', () {
      // Outer ring spans 0.8 → 1.0 over 40 px; 20 px further out → 1.1.
      expect(radius(mapping.toTarget(const Point2(500, 620))), closeTo(1.1, 1e-9));
    });

    test('scores follow the painted rings, not the ideal ones', () {
      final model = TargetModel.ikthof();
      // 0.21 of the outer radius: inside the painted bull (0.22) although
      // outside the ideal one (0.2), so it scores 5.
      expect(model.scoreAt(mapping.toTarget(Point2(500, 400 + 200 * 0.21))), 5);
      // 0.61: inside the painted 0.62 edge, so still ring 3 (ideal would say 2).
      expect(model.scoreAt(mapping.toTarget(Point2(500, 400 + 200 * 0.61))), 3);
    });

    test('directions: up in the image is +v, right is +u', () {
      final up = mapping.toTarget(const Point2(500, 300));
      expect(up.y, greaterThan(0));
      expect(up.x.abs(), lessThan(1e-9));
      final right = mapping.toTarget(const Point2(600, 400));
      expect(right.x, greaterThan(0));
      expect(right.y.abs(), lessThan(1e-9));
    });
  });

  group('end to end on rendered camera views: find, calibrate, map, score each knife', () {
    // Rendered by tool/render_camera_views.dart with known entry points and
    // scores (scored against the board's painted rings).
    final truth = jsonDecode(File('test/fixtures/camera-views/truth.json').readAsStringSync()) as Map<String, dynamic>;
    final model = TargetModel.ikthof();
    for (final name in truth.keys) {
      final knives = (truth[name] as Map<String, dynamic>)['knives'] as List;
      if (knives.isEmpty) continue;
      test(name, () {
        final image = decodeToRgb(File('test/fixtures/camera-views/$name').readAsBytesSync())!;
        final found = buildTargetLocator(boundaries).locate(image) as TargetFound;
        final mapping = TargetMapping(TargetCalibration(
          imageWidth: image.width,
          imageHeight: image.height,
          boundaries: found.boundaries,
          outer: found.outer,
        ));
        for (final k in knives.cast<Map<String, dynamic>>()) {
          final pixel = (k['entryPixel'] as List).cast<num>();
          final expected = (k['entryNormalised'] as List).cast<num>();
          final point = mapping.toTarget(Point2(pixel[0].toDouble(), pixel[1].toDouble()));
          expect(model.scoreAt(point), k['score'], reason: 'knife at $expected mapped to $point');
          // The renders' entry points are in the board's own units, where the
          // painted edges sit at [paintedEdges]; the mapping gives the
          // equivalent radius on the ideal scale (painted edge k ↦ ideal k).
          final onBoard = math.sqrt(expected[0] * expected[0] + expected[1] * expected[1]);
          expect(radius(point), closeTo(idealEquivalent(onBoard), 0.01), reason: 'knife at $expected mapped to $point');
        }
      });
    }
  });
}
