import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/game/area_board.dart';
import 'package:thrower_app/vision/ellipse.dart';

/// [n] points a finger drew round an ellipse centred at ([cx], [cy]) with
/// radii [rx] × [ry] (axis-aligned).
List<Point2> loop(double cx, double cy, double rx, double ry, {int n = 40}) => [
  for (var i = 0; i < n; i++) Point2(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)),
];

/// A finger drawn round [corners] ([perEdge] points along each edge), each
/// point nudged up to [wobble] px either way (a steady pattern, not random).
List<Point2> polygonLoop(List<Point2> corners, {int perEdge = 15, double wobble = 0}) => [
  for (var c = 0; c < corners.length; c++)
    for (var i = 0; i < perEdge; i++)
      () {
        final a = corners[c], b = corners[(c + 1) % corners.length], t = i / perEdge;
        final k = c * perEdge + i;
        return Point2(
          a.x + (b.x - a.x) * t + wobble * ((k * 37 % 7) - 3) / 3,
          a.y + (b.y - a.y) * t + wobble * ((k * 53 % 7) - 3) / 3,
        );
      }(),
];

/// Whether [found] has a corner within [tolerance] px of each of [expected].
Matcher hasCornersNear(List<Point2> expected, {double tolerance = 6}) => predicate<List<Point2>?>(
  (found) =>
      found != null &&
      found.length == 4 &&
      expected.every((e) => found.any((f) => math.sqrt(math.pow(f.x - e.x, 2) + math.pow(f.y - e.y, 2)) <= tolerance)),
  'corners within $tolerance px of $expected',
);

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

  // Round or four-cornered (story-checkpoint-board-outlines, Nigel 2026-10-21).
  group('round or four-cornered', () {
    List<Point2>? outlineOf(List<Point2> points) => areaBoard(points, imageWidth: 720, imageHeight: 1280)?.outline;

    final round = <(String, List<Point2>)>[
      ('a circle', loop(300, 500, 120, 120)),
      ('a round board seen from the side', loop(300, 500, 150, 75)),
      ('a wobbly circle', [
        for (final (i, p) in loop(360, 640, 200, 190).indexed) Point2(p.x + (i.isEven ? 6 : -6), p.y + (i % 3 - 1) * 5),
      ]),
    ];
    for (final (name, points) in round) {
      test('$name stays round', () => expect(outlineOf(points), isNull));
    }

    final square = [const Point2(200, 400), const Point2(440, 400), const Point2(440, 640), const Point2(200, 640)];
    final cornered = <(String, List<Point2>)>[
      ('a square', square),
      ('a rectangle', [const Point2(150, 400), const Point2(550, 400), const Point2(550, 650), const Point2(150, 650)]),
      // Seen from one side: the near edge taller than the far one.
      ('a rectangle in perspective', [const Point2(150, 380), const Point2(500, 440), const Point2(500, 620), const Point2(150, 680)]),
      ('a square turned on its corner', [const Point2(360, 400), const Point2(500, 540), const Point2(360, 680), const Point2(220, 540)]),
    ];
    for (final (name, corners) in cornered) {
      test('$name becomes four corners where it was drawn', () {
        expect(outlineOf(polygonLoop(corners)), hasCornersNear(corners));
      });
    }

    test('a sloppy square still has four corners, near the drawn ones', () {
      expect(outlineOf(polygonLoop(square, wobble: 12)), hasCornersNear(square, tolerance: 20));
    });

    // A hand wanders smoothly rather than jittering: up to [amp] px.
    List<Point2> wander(List<Point2> points, double amp) => [
      for (final (i, p) in points.indexed)
        Point2(p.x + amp * math.sin(i * 0.31 + 1) * math.cos(i * 0.07), p.y + amp * math.cos(i * 0.23) * math.sin(i * 0.11 + 2)),
    ];

    test('drawn shakily (20 px off course): a circle stays round, a square and a rectangle in perspective keep corners', () {
      expect(outlineOf(wander(loop(320, 520, 120, 120, n: 80), 20)), isNull);
      expect(outlineOf(wander(loop(320, 520, 150, 75, n: 80), 20)), isNull);
      expect(outlineOf(wander(polygonLoop(square, perEdge: 20), 20)), isNotNull);
      final perspective = [const Point2(150, 380), const Point2(500, 440), const Point2(500, 620), const Point2(150, 680)];
      expect(outlineOf(wander(polygonLoop(perspective, perEdge: 20), 20)), isNotNull);
    });

    test('the oval is kept too (the board is never scored, but the code needs a centre)', () {
      final b = areaBoard(polygonLoop(square), imageWidth: 720, imageHeight: 1280)!;
      expect(b.outer.cx, closeTo(320, 2));
      expect(b.outer.cy, closeTo(520, 2));
    });

    test('a board running off the picture is cut at its edge', () {
      // A square whose left side is 40 px beyond the picture.
      final corners = [const Point2(-40, 400), const Point2(200, 400), const Point2(200, 640), const Point2(-40, 640)];
      final outline = outlineOf(polygonLoop(corners))!;
      expect(outline.every((p) => p.x >= 0 && p.x <= 720 && p.y >= 0 && p.y <= 1280), isTrue, reason: '$outline');
      expect(outline, hasCornersNear([const Point2(0, 400), const Point2(200, 400), const Point2(200, 640), const Point2(0, 640)]));
    });
  });
}
