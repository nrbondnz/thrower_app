import 'dart:math' as math;

import '../vision/board_shape.dart';
import '../vision/ellipse.dart';
import '../vision/target_calibration.dart';

/// Quick draw's **drawn** boards (Mark, 2026-10-21: "draw his finger round
/// the board as a single hit point, not worrying about rings for scoring,
/// just relying on hit time in the area he draws"). The loop the finger drew
/// round a board, in the upright picture's pixels ([imageWidth] ×
/// [imageHeight]), as a board: the ellipse that best fits the loop, or, if
/// the loop has corners (a square or rectangular board, Nigel 2026-10-21),
/// four corners ([boardOutline]). The corners stay where they were drawn: a
/// rectangle seen from the side isn't one in the picture. The loop is cut at
/// the picture's edge first. Its rings are the ellipse scaled (0.2 … 0.8):
/// the entry-point code needs a centre ring, but a drawn board is never
/// scored (`QuickDrawTargets.areas`). Null if the loop is too short or too
/// small to be a board, or too flat to be a fair fit.
TargetCalibration? areaBoard(List<Point2> loop, {required int imageWidth, required int imageHeight}) {
  if (loop.length < minLoopPoints) return null;
  final inPicture = [
    for (final p in loop)
      Point2(p.x.clamp(0, imageWidth.toDouble()).toDouble(), p.y.clamp(0, imageHeight.toDouble()).toDouble()),
  ];
  final outer = fitEllipse(inPicture);
  if (outer == null || !outer.semiMajor.isFinite || !outer.semiMinor.isFinite) return null;
  final shorter = math.min(imageWidth, imageHeight);
  final small = math.min(outer.semiMajor, outer.semiMinor), large = math.max(outer.semiMajor, outer.semiMinor);
  if (small < shorter * minAreaRadius || large > shorter) return null;
  if (small < large * minRoundness) return null;
  return TargetCalibration(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    boundaries: {for (final r in const [0.2, 0.4, 0.6, 0.8]) r: outer.scaled(r)},
    outer: outer,
    outline: boardOutline(inPicture, outer),
  );
}

/// The four corners of a loop drawn round a square or rectangular board, or
/// null if the loop is round enough for [oval]. The corners are the four
/// loop points enclosing the most area (on its convex hull); the outline
/// wins only when the loop keeps closer to it than to the oval: its mean
/// miss (`BoardShape.reach` from 1) is under the oval's by [cornerMargin].
/// A circle misses the square inside it by far more than it misses its oval
/// (0.27 to 0, still 0.15 to 0.09 drawn very shakily); a square misses its
/// oval at the corners and edges (0.10 to 0; 0.12 to 0.10 very shakily).
List<Point2>? boardOutline(List<Point2> loop, Ellipse oval) {
  final hull = convexHull(loop);
  if (hull.length < 4) return null;
  final corners = _largestQuad(hull);
  final quad = OutlineShape(corners), round = EllipseShape(oval);
  double miss(BoardShape s) => loop.fold(0.0, (sum, p) => sum + (s.reach(p) - 1).abs()) / loop.length;
  return miss(quad) + cornerMargin < miss(round) ? corners : null;
}

/// The convex hull of [points] (Andrew's monotone chain), anticlockwise in
/// the picture's axes, without repeated or in-line points.
List<Point2> convexHull(List<Point2> points) {
  final sorted = [...points]..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  if (sorted.length < 3) return sorted;
  double cross(Point2 o, Point2 a, Point2 b) => (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
  List<Point2> chain(Iterable<Point2> ps) {
    final out = <Point2>[];
    for (final p in ps) {
      while (out.length >= 2 && cross(out[out.length - 2], out.last, p) <= 0) {
        out.removeLast();
      }
      out.add(p);
    }
    return out..removeLast();
  }

  return [...chain(sorted), ...chain(sorted.reversed)];
}

/// The four of [hull]'s points (in order round it) enclosing the most area:
/// for each diagonal (i, k), the best point on each side of it.
List<Point2> _largestQuad(List<Point2> hull) {
  final n = hull.length;
  double triangle(Point2 a, Point2 b, Point2 c) => ((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)).abs() / 2;
  var best = -1.0;
  var corners = hull.take(4).toList();
  for (var i = 0; i < n; i++) {
    for (var k = i + 2; k < n; k++) {
      var sideA = -1.0, sideB = -1.0, j = -1, l = -1;
      for (var m = i + 1; m < k; m++) {
        final t = triangle(hull[i], hull[m], hull[k]);
        if (t > sideA) (sideA, j) = (t, m);
      }
      for (var m = k + 1; m < n + i; m++) {
        final t = triangle(hull[i], hull[k], hull[m % n]);
        if (t > sideB) (sideB, l) = (t, m % n);
      }
      if (j < 0 || l < 0 || l == i) continue;
      if (sideA + sideB > best) {
        best = sideA + sideB;
        corners = [hull[i], hull[j], hull[k], hull[l]];
      }
    }
  }
  return corners;
}

/// See [areaBoard]: the fewest points a drawn loop needs, the smallest
/// board radius (a share of the picture's shorter side), and the flattest
/// ellipse accepted (minor ÷ major: a board seen from the side is ~0.5).
const minLoopPoints = 8;
const minAreaRadius = 0.03;
const minRoundness = 0.35;

/// See [boardOutline]: how much closer (in mean reach) the loop must keep to
/// four corners than to the oval for the board to be four-cornered: a small
/// lean to the oval, so a loop that fits both about as well stays round.
const cornerMargin = 0.01;
