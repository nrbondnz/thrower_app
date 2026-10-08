import 'dart:math' as math;

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
  });

  /// Size of the upright image the ellipses are measured in.
  final int imageWidth;
  final int imageHeight;

  /// Fitted ring edges, keyed by normalised radius (0.2 … 0.8).
  final Map<double, Ellipse> boundaries;

  /// Outer edge of the outermost scoring ring (normalised radius 1).
  final Ellipse outer;

  /// End of the outer ellipse's long axis: the handle for turning/stretching it.
  Point2 get majorHandle => outer.pointAt(0);

  /// End of the outer ellipse's short axis: the handle for stretching it.
  Point2 get minorHandle => outer.pointAt(math.pi / 2);

  /// Everything moved by ([dx], [dy]) image pixels.
  TargetCalibration moved(double dx, double dy) => _map((e) => e.translated(dx, dy), outer.translated(dx, dy));

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

    return _map(apply, apply(outer));
  }

  TargetCalibration _map(Ellipse Function(Ellipse) f, Ellipse newOuter) => TargetCalibration(
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        boundaries: {for (final e in boundaries.entries) e.key: f(e.value)},
        outer: newOuter,
      );
}
