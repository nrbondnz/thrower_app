import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/target_camera.dart';
import 'package:thrower_app/game/board_crop.dart';
import 'package:thrower_app/vision/board_shape.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/luma_image.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/throw_classifier.dart';


/// A square board 80 px across, centred at (100, 100), in a 200 × 200
/// picture, its oval the circle inside it.
TargetCalibration squareBoard() {
  const circle = Ellipse(cx: 100, cy: 100, semiMajor: 40, semiMinor: 40, angle: 0);
  return TargetCalibration(
    imageWidth: 200,
    imageHeight: 200,
    boundaries: {for (final r in const [0.2, 0.4, 0.6, 0.8]) r: circle.scaled(r)},
    outer: circle,
    outline: const [Point2(60, 60), Point2(140, 60), Point2(140, 140), Point2(60, 140)],
  );
}

void main() {
  group('EllipseShape: a ring board, as before', () {
    const e = Ellipse(cx: 50, cy: 40, semiMajor: 30, semiMinor: 10, angle: math.pi / 6);
    const shape = EllipseShape(e);

    test('reach is the normalised radius', () {
      for (final p in const [Point2(50, 40), Point2(70, 50), Point2(10, 0)]) {
        expect(shape.reach(p), e.normalisedRadius(p));
      }
    });

    test('the box is the turned ellipse\'s', () {
      final (:halfWidth, :halfHeight) = shape.halfExtent;
      final c = math.cos(e.angle), s = math.sin(e.angle);
      expect(halfWidth, closeTo(math.sqrt(math.pow(30 * c, 2) + math.pow(10 * s, 2)), 1e-9));
      expect(halfHeight, closeTo(math.sqrt(math.pow(30 * s, 2) + math.pow(10 * c, 2)), 1e-9));
    });

    test('area and mean radius', () {
      expect(shape.area, closeTo(math.pi * 300, 1e-9));
      expect(shape.meanRadius, 20);
    });
  });

  group('OutlineShape: four corners', () {
    final square = OutlineShape(const [Point2(0, 0), Point2(10, 0), Point2(10, 10), Point2(0, 10)]);

    final reaches = <(String, Point2, double)>[
      ('the centre', const Point2(5, 5), 0),
      ('the middle of an edge', const Point2(10, 5), 1),
      ('a corner', const Point2(10, 10), 1),
      ('halfway to an edge', const Point2(7.5, 5), 0.5),
      ('outside, half as far again', const Point2(5, 12.5), 1.5),
    ];
    for (final (name, p, expected) in reaches) {
      test('reach at $name is $expected', () => expect(square.reach(p), closeTo(expected, 1e-9)));
    }

    test('the corners can go round either way', () {
      final backwards = OutlineShape(const [Point2(0, 10), Point2(10, 10), Point2(10, 0), Point2(0, 0)]);
      expect(backwards.reach(const Point2(10, 5)), closeTo(1, 1e-9));
      expect(backwards.reach(const Point2(5, 12.5)), closeTo(1.5, 1e-9));
    });

    test('a rectangle seen from the side (wider near, narrower far): inside and outside', () {
      final seen = OutlineShape(const [Point2(0, 0), Point2(40, 10), Point2(40, 50), Point2(0, 60)]);
      expect(seen.reach(const Point2(38, 30)), lessThan(1));
      expect(seen.reach(const Point2(39, 5)), greaterThan(1), reason: 'above the far edge, which slopes down');
      expect(seen.reach(const Point2(2, 2)), lessThan(1), reason: 'inside the near corner');
    });

    test('box, area and mean radius', () {
      expect(square.centre.x, 5);
      expect(square.halfExtent, (halfWidth: 5.0, halfHeight: 5.0));
      expect(square.area, 100);
      expect(square.meanRadius, 5);
    });

    test('rescaled and moved', () {
      final moved = square.rescaled(2).translated(1, 0) as OutlineShape;
      expect(moved.corners[2], isA<Point2>().having((p) => (p.x, p.y), 'corner', (21.0, 20.0)));
      expect(moved.area, 400);
    });
  });

  group('a board with an outline', () {
    test('its shape is the outline; a round board\'s is its outer ring', () {
      expect(squareBoard().shape, isA<OutlineShape>());
      final round = squareBoard();
      expect(
        TargetCalibration(
          imageWidth: 200,
          imageHeight: 200,
          boundaries: round.boundaries,
          outer: round.outer,
        ).shape,
        isA<EllipseShape>(),
      );
    });

    test('moving, cropping and stretching take the corners along', () {
      final b = squareBoard();
      expect(b.moved(5, -5).outline!.first, isA<Point2>().having((p) => (p.x, p.y), 'corner', (65.0, 55.0)));
      expect(b.within(50, 50, 100, 100).outline!.first, isA<Point2>().having((p) => (p.x, p.y), 'corner', (10.0, 10.0)));
      // The long-axis handle dragged twice as far out: every corner twice as far along x from the centre.
      final stretched = b.withMajorHandleAt(const Point2(180, 100));
      expect(stretched.outline![1].x, closeTo(180, 1e-9));
      expect(stretched.outline![1].y, closeTo(60, 1e-9));
    });

    test('the watched region is the outline\'s box, grown by the margin', () {
      final r = WatchRegion.fromCalibration(squareBoard());
      expect((r.left, r.top, r.right, r.bottom), (0.2, 0.2, 0.8, 0.8));
    });

    test('the crop is centred on the outline', () {
      final b = squareBoard();
      final (:camera, :calibration) = cropToBoard(_StillCamera(), b);
      expect((camera.x + camera.width / 2, camera.y + camera.height / 2), (100, 100));
      expect(calibration.outline, isNotNull);
    });

    test('the smallest knife is a share of the outline\'s area', () {
      expect(minKnifeArea(squareBoard(), 200), closeTo(0.0025 * 6400, 1e-9));
    });

    // The point of an outline: a knife in a square board's corner is on the
    // board, though outside the circle inside it.
    test('a knife in the corner of a square board counts; with the circle alone it would not', () {
      final before = LumaImage(200, 200, Uint8List(200 * 200)..fillRange(0, 200 * 200, 100));
      final pixels = Uint8List.fromList(before.pixels);
      // A short blade at the top-left corner, (62–68, 62–64): beyond the circle (radius 40 from (100, 100)).
      for (var y = 62; y <= 64; y++) {
        for (var x = 62; x <= 68; x++) {
          pixels[y * 200 + x] = 230;
        }
      }
      final after = LumaImage(200, 200, pixels);
      expect(findNewObject(before, after, squareBoard(), threshold: 30), isNotNull);
      final circleOnly = TargetCalibration(
        imageWidth: 200,
        imageHeight: 200,
        boundaries: squareBoard().boundaries,
        outer: squareBoard().outer,
      );
      expect(findNewObject(before, after, circleOnly, threshold: 30, searchMargin: 1.5), isNull);
    });
  });
}

/// Only its rotation matters to [cropToBoard].
class _StillCamera extends Fake implements TargetCamera {
  @override
  int get uprightRotation => 0;
}
