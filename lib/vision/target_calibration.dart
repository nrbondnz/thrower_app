import 'dart:math' as math;

import 'board_shape.dart';
import 'ellipse.dart';

/// The target's ring edges in the upright camera image, as found by the ring
/// finder and possibly adjusted by hand. Once locked, this is what throws are
/// scored against for the rest of the session (the camera doesn't move).
///
/// Adjustments act on **all rings together**, driven by the outer ellipse
/// (normalised radius 1): moving, turning and stretching its long axis, or
/// stretching its short axis. That keeps the rings in proportion and keeps the
/// small offsets between their centres that perspective produces.
class TargetCalibration {
  const TargetCalibration({
    required this.imageWidth,
    required this.imageHeight,
    required this.boundaries,
    required this.outer,
    this.outline,
  });

  /// Size of the upright image the ellipses are measured in.
  final int imageWidth;
  final int imageHeight;

  /// Fitted ring edges, keyed by normalised radius (0.2 … 0.8).
  final Map<double, Ellipse> boundaries;

  /// Outer edge of the outermost scoring ring (normalised radius 1).
  final Ellipse outer;

  /// The board's corners, for a Quick draw board drawn round a square or
  /// rectangular board (story-checkpoint-board-outlines); null for a round
  /// board. When set, it is the board's edge ([shape]), and [outer] is only
  /// the oval nearest it (the board is never scored).
  final List<Point2>? outline;

  /// The board's edge, as throw detection asks it: the [outline] if there is
  /// one, else the [outer] ring.
  BoardShape get shape {
    final corners = outline;
    return corners == null ? EllipseShape(outer) : OutlineShape(corners);
  }

  /// End of the outer ellipse's long axis: the handle for turning/stretching it.
  Point2 get majorHandle => outer.pointAt(0);

  /// End of the outer ellipse's short axis: the handle for stretching it.
  Point2 get minorHandle => outer.pointAt(math.pi / 2);

  /// Everything moved by ([dx], [dy]) image pixels.
  TargetCalibration moved(double dx, double dy) => _map(
        (e) => e.translated(dx, dy),
        outer.translated(dx, dy),
        (p) => Point2(p.x + dx, p.y + dy),
      );

  /// The long-axis handle dragged to [to]: the long axis turns to point at it
  /// and stretches to reach it; every ring turns and stretches the same way
  /// about the outer centre.
  TargetCalibration withMajorHandleAt(Point2 to) {
    final dx = to.x - outer.cx, dy = to.y - outer.cy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1) return this;
    final factor = length / outer.semiMajor;
    final turn = math.atan2(dy, dx) - outer.angle;
    return _transform(majorFactor: factor, minorFactor: 1, turn: turn);
  }

  /// The short-axis handle dragged to [to]: the short axis stretches to reach
  /// it (measured along the short axis); every ring's short axis stretches the
  /// same way.
  TargetCalibration withMinorHandleAt(Point2 to) {
    final dirX = -math.sin(outer.angle), dirY = math.cos(outer.angle);
    final reach = ((to.x - outer.cx) * dirX + (to.y - outer.cy) * dirY).abs();
    if (reach < 1) return this;
    return _transform(majorFactor: 1, minorFactor: reach / outer.semiMinor, turn: 0);
  }

  /// The outline's corner [index] dragged to [to], kept inside the picture
  /// (Adjust boards on a four-cornered board). Ignored if it would fold the
  /// outline (no longer convex) or there is no outline.
  TargetCalibration withCornerAt(int index, Point2 to) {
    final corners = outline;
    if (corners == null || index < 0 || index >= corners.length) return this;
    final inPicture = Point2(to.x.clamp(0, imageWidth).toDouble(), to.y.clamp(0, imageHeight).toDouble());
    final next = [...corners]..[index] = inPicture;
    if (!isConvex(next)) return this;
    return TargetCalibration(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      boundaries: boundaries,
      outer: outer,
      outline: next,
    );
  }

  /// The same rings in the [w] × [h] part of the image whose top-left corner
  /// is ([x], [y]) (Quick draw watches each board in its own crop).
  TargetCalibration within(int x, int y, int w, int h) => TargetCalibration(
        imageWidth: w,
        imageHeight: h,
        boundaries: {for (final e in boundaries.entries) e.key: e.value.translated(-x.toDouble(), -y.toDouble())},
        outer: outer.translated(-x.toDouble(), -y.toDouble()),
        outline: outline == null ? null : [for (final p in outline!) Point2(p.x - x, p.y - y)],
      );

  TargetCalibration _transform({required double majorFactor, required double minorFactor, required double turn}) {
    // Stretch along the outer ellipse's own axes, then turn, about its centre.
    final c = math.cos(outer.angle), s = math.sin(outer.angle);
    Point2 point(double x, double y) {
      final rx = x - outer.cx, ry = y - outer.cy;
      final u = (rx * c + ry * s) * majorFactor, v = (-rx * s + ry * c) * minorFactor;
      final a = outer.angle + turn;
      return Point2(outer.cx + u * math.cos(a) - v * math.sin(a), outer.cy + u * math.sin(a) + v * math.cos(a));
    }

    Ellipse apply(Ellipse e) {
      final centre = point(e.cx, e.cy);
      // Ring axes are near the outer's; stretch each by the factor of the
      // outer axis it lines up with.
      final aligned = math.cos(e.angle - outer.angle).abs() > math.sqrt1_2;
      return Ellipse(
        cx: centre.x,
        cy: centre.y,
        semiMajor: e.semiMajor * (aligned ? majorFactor : minorFactor),
        semiMinor: e.semiMinor * (aligned ? minorFactor : majorFactor),
        angle: e.angle + turn,
      );
    }

    return _map(apply, apply(outer), (p) => point(p.x, p.y));
  }

  /// Every ring by [f], the outer ring as [newOuter], and the outline's
  /// corners by [corner].
  TargetCalibration _map(Ellipse Function(Ellipse) f, Ellipse newOuter, Point2 Function(Point2) corner) =>
      TargetCalibration(
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        boundaries: {for (final e in boundaries.entries) e.key: f(e.value)},
        outer: newOuter,
        outline: outline == null ? null : [for (final p in outline!) corner(p)],
      );
}

/// Whether [corners], in order, turn the same way at every corner (a convex
/// outline, which `OutlineShape.reach` needs).
bool isConvex(List<Point2> corners) {
  var sign = 0;
  for (var i = 0; i < corners.length; i++) {
    final a = corners[i], b = corners[(i + 1) % corners.length], c = corners[(i + 2) % corners.length];
    final turn = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
    if (turn == 0) continue;
    final s = turn > 0 ? 1 : -1;
    if (sign != 0 && s != sign) return false;
    sign = s;
  }
  return sign != 0;
}
