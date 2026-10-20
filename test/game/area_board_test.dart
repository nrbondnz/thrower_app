import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/game/area_board.dart';
import 'package:thrower_app/vision/ellipse.dart';

/// [n] points a finger drew round an ellipse centred at ([cx], [cy]) with
/// radii [rx] × [ry] (axis-aligned).
List<Point2> loop(double cx, double cy, double rx, double ry, {int n = 40}) => [
  for (var i = 0; i < n; i++) Point2(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)),
];

void main() {
  group('areaBoard: a loop drawn round a board', () {
    test('a circle becomes a board at its centre with its radius', () {
      final b = areaBoard(loop(300, 500, 120, 120), imageWidth: 720, imageHeight: 1280)!;
      expect(b.outer.cx, closeTo(300, 0.5));
      expect(b.outer.cy, closeTo(500, 0.5));
      expect(b.outer.semiMajor, closeTo(120, 0.5));
      expect(b.outer.semiMinor, closeTo(120, 0.5));
    });

    test('a board seen from the side (an oval) keeps its shape', () {
      final b = areaBoard(loop(300, 500, 150, 75), imageWidth: 720, imageHeight: 1280)!;
      final radii = [b.outer.semiMajor, b.outer.semiMinor]..sort();
      expect(radii[0], closeTo(75, 0.5));
      expect(radii[1], closeTo(150, 0.5));
    });

    test('the board is in the picture\'s size, with rings the same ellipse scaled', () {
      final b = areaBoard(loop(300, 500, 120, 120), imageWidth: 720, imageHeight: 1280)!;
      expect((b.imageWidth, b.imageHeight), (720, 1280));
      expect(b.boundaries.keys, [0.2, 0.4, 0.6, 0.8]);
      expect(b.boundaries[0.2]!.semiMajor, closeTo(24, 0.5));
    });

    test('a wobbly hand-drawn loop still fits', () {
      final wobbly = [
        for (final (i, p) in loop(360, 640, 200, 190).indexed) Point2(p.x + (i.isEven ? 6 : -6), p.y + (i % 3 - 1) * 5),
      ];
      final b = areaBoard(wobbly, imageWidth: 720, imageHeight: 1280)!;
      expect(b.outer.cx, closeTo(360, 5));
      expect(b.outer.cy, closeTo(640, 5));
    });

    final rejected = <(String, List<Point2>)>[
      ('too few points (a tap, not a loop)', loop(300, 500, 120, 120, n: minLoopPoints - 1)),
      ('too small to be a board', loop(300, 500, 10, 10)),
      ('bigger than the picture', loop(300, 500, 800, 800)),
      ('too flat for a fair fit', loop(300, 500, 200, 40)),
      ('a straight line', [for (var i = 0; i < 20; i++) Point2(100.0 + i * 10, 400)]),
    ];
    for (final (name, points) in rejected) {
      test('$name: no board', () {
        expect(areaBoard(points, imageWidth: 720, imageHeight: 1280), isNull);
      });
    }
  });
}
