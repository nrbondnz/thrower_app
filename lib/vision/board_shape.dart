import 'dart:math' as math;

import 'ellipse.dart';

/// A board's edge in the picture, as throw detection needs it: is a point on
/// the board (or within a margin of it), where is the board, how big is it.
/// Ring boards are an oval ([EllipseShape]); a Quick draw board drawn round a
/// square or rectangular board is a four-cornered outline ([OutlineShape],
/// story-checkpoint-board-outlines, 2026-10-21).
abstract class BoardShape {
  /// 1 on the edge, under 1 inside, 0 at the [centre]; the shape scaled by k
  /// about its centre is where this is k (as an ellipse's normalised radius).
  double reach(Point2 p);

  Point2 get centre;

  /// Half the width and height of the box round the shape, centred on
  /// [centre].
  ({double halfWidth, double halfHeight}) get halfExtent;

  /// The shape's area, in square pixels.
  double get area;

  /// A typical radius: half the box's average side (a circle's radius).
  double get meanRadius;

  /// Every coordinate multiplied by [factor].
  BoardShape rescaled(double factor);

  BoardShape translated(double dx, double dy);
}

/// A ring board's outer edge.
class EllipseShape implements BoardShape {
  const EllipseShape(this.ellipse);

  final Ellipse ellipse;

  @override
  double reach(Point2 p) => ellipse.normalisedRadius(p);

  @override
  Point2 get centre => Point2(ellipse.cx, ellipse.cy);

  @override
  ({double halfWidth, double halfHeight}) get halfExtent {
    final e = ellipse, c = math.cos(e.angle), s = math.sin(e.angle);
    return (
      halfWidth: math.sqrt(math.pow(e.semiMajor * c, 2) + math.pow(e.semiMinor * s, 2)),
      halfHeight: math.sqrt(math.pow(e.semiMajor * s, 2) + math.pow(e.semiMinor * c, 2)),
    );
  }

  @override
  double get area => math.pi * ellipse.semiMajor * ellipse.semiMinor;

  @override
  double get meanRadius => (ellipse.semiMajor + ellipse.semiMinor) / 2;

  @override
  BoardShape rescaled(double factor) => EllipseShape(ellipse.rescaled(factor));

  @override
  BoardShape translated(double dx, double dy) => EllipseShape(ellipse.translated(dx, dy));
}

/// A convex outline, its corners in order round it (either way): a square or
/// rectangular board as the camera sees it, so not necessarily square
/// (perspective). Its [centre] is the corners' average, which is inside.
class OutlineShape implements BoardShape {
  OutlineShape(this.corners)
      : assert(corners.length >= 3),
        centre = Point2(
          corners.fold(0.0, (s, p) => s + p.x) / corners.length,
          corners.fold(0.0, (s, p) => s + p.y) / corners.length,
        );

  final List<Point2> corners;

  @override
  final Point2 centre;

  @override
  double reach(Point2 p) {
    // For each edge: how far p is towards it from the centre, as a share of
    // the edge's own distance from the centre. The largest is the scale at
    // which the outline passes through p.
    var most = 0.0;
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i], b = corners[(i + 1) % corners.length];
      // A normal to the edge, pointing away from the centre.
      var nx = b.y - a.y, ny = a.x - b.x;
      var edge = nx * (a.x - centre.x) + ny * (a.y - centre.y);
      if (edge < 0) {
        nx = -nx;
        ny = -ny;
        edge = -edge;
      }
      if (edge <= 0) continue;
      most = math.max(most, (nx * (p.x - centre.x) + ny * (p.y - centre.y)) / edge);
    }
    return most;
  }

  @override
  ({double halfWidth, double halfHeight}) get halfExtent => (
        halfWidth: corners.fold(0.0, (m, p) => math.max(m, (p.x - centre.x).abs())),
        halfHeight: corners.fold(0.0, (m, p) => math.max(m, (p.y - centre.y).abs())),
      );

  @override
  double get area {
    var twice = 0.0;
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i], b = corners[(i + 1) % corners.length];
      twice += a.x * b.y - b.x * a.y;
    }
    return twice.abs() / 2;
  }

  @override
  double get meanRadius {
    final (:halfWidth, :halfHeight) = halfExtent;
    return (halfWidth + halfHeight) / 2;
  }

  @override
  BoardShape rescaled(double factor) => OutlineShape([for (final p in corners) Point2(p.x * factor, p.y * factor)]);

  @override
  BoardShape translated(double dx, double dy) => OutlineShape([for (final p in corners) Point2(p.x + dx, p.y + dy)]);
}
