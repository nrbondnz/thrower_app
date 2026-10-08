import 'dart:math' as math;

import '../scoring/target_model.dart';
import 'ellipse.dart';
import 'target_calibration.dart';

/// Converts points in the camera image to normalised target coordinates
/// ([TargetPoint]) using a calibration's **measured** ring edges.
///
/// Hand-painted rings aren't at the ideal radii (the reference board's are at
/// 0.219 / 0.395 / 0.620 of the 0.8 edge, not 0.2 / 0.4 / 0.6), so a single
/// overall stretch would score knives near a line wrongly. Instead, along the
/// line from the bull's centre through the point, the point's distance is
/// placed between the painted edges either side of it, and given the
/// matching share of the radius between their ideal values. A point exactly on
/// a painted edge therefore gets exactly that edge's radius, and `TargetModel`
/// scores the board as painted, line-touch rule included. Each edge is its own
/// fitted ellipse, so perspective (rings not quite concentric) is handled.
///
/// Inside the bull the radius grows in proportion to distance from the centre;
/// beyond the outer edge (radius 1) it carries on at the outermost ring's rate.
/// The angle comes from the outer ellipse's own axes (it doesn't affect score).
class TargetMapping {
  TargetMapping(TargetCalibration calibration)
      : _edges = [
          ...[for (final e in calibration.boundaries.entries) (e.key, e.value)]..sort((a, b) => a.$1.compareTo(b.$1)),
          (1.0, calibration.outer),
        ],
        _outer = calibration.outer;

  /// (normalised radius, fitted ellipse), centre outwards, ending at radius 1.
  final List<(double, Ellipse)> _edges;
  final Ellipse _outer;

  /// The bull's edge is the innermost boundary; its centre is the target's.
  late final Point2 _bullCentre = Point2(_edges.first.$2.cx, _edges.first.$2.cy);

  /// The target point at image pixel [p].
  TargetPoint toTarget(Point2 p) {
    final dx = p.x - _bullCentre.x, dy = p.y - _bullCentre.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    final r = distance < 1e-9 ? 0.0 : _radius(distance, dx / distance, dy / distance);

    // Direction on the target from the outer ellipse's frame (v up).
    final c = math.cos(_outer.angle), s = math.sin(_outer.angle);
    final u = (dx * c + dy * s) / _outer.semiMajor, w = (-dx * s + dy * c) / _outer.semiMinor;
    // Image y runs down; un-rotate so the result is in image orientation, then
    // flip y so v is up.
    final ix = u * c - w * s, iy = u * s + w * c;
    final len = math.sqrt(ix * ix + iy * iy);
    if (len < 1e-12) return const TargetPoint(0, 0);
    return TargetPoint(r * ix / len, -r * iy / len);
  }

  double _radius(double distance, double ux, double uy) {
    // Distance from the bull's centre to each edge along this direction.
    final reach = [for (final (_, e) in _edges) _rayToEdge(e, ux, uy)];
    if (distance <= reach.first) return _edges.first.$1 * distance / reach.first;
    for (var k = 0; k + 1 < _edges.length; k++) {
      if (distance <= reach[k + 1]) {
        final t = (distance - reach[k]) / (reach[k + 1] - reach[k]);
        return _edges[k].$1 + t * (_edges[k + 1].$1 - _edges[k].$1);
      }
    }
    final n = _edges.length;
    final rate = (_edges[n - 1].$1 - _edges[n - 2].$1) / (reach[n - 1] - reach[n - 2]);
    return 1 + (distance - reach[n - 1]) * rate;
  }

  /// How far from the bull's centre, in direction (ux, uy), the ray meets [e].
  double _rayToEdge(Ellipse e, double ux, double uy) {
    final c = math.cos(e.angle), s = math.sin(e.angle);
    // Ray origin and direction in the ellipse's own frame, scaled to a circle.
    final ox = ((_bullCentre.x - e.cx) * c + (_bullCentre.y - e.cy) * s) / e.semiMajor;
    final oy = (-(_bullCentre.x - e.cx) * s + (_bullCentre.y - e.cy) * c) / e.semiMinor;
    final dx = (ux * c + uy * s) / e.semiMajor, dy = (-ux * s + uy * c) / e.semiMinor;
    final a = dx * dx + dy * dy, b = 2 * (ox * dx + oy * dy), cc = ox * ox + oy * oy - 1;
    final disc = b * b - 4 * a * cc;
    return (-b + math.sqrt(math.max(0, disc))) / (2 * a);
  }
}
