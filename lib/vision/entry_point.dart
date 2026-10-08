import 'dart:math' as math;

import 'ellipse.dart';
import 'rgb_image.dart';
import 'target_calibration.dart';

/// Where a newly stuck knife's blade entered the board, in image pixels.
class EntryEstimate {
  const EntryEstimate({required this.point, required this.axis, required this.knifePixels});

  /// The entry point (image pixels of the before/after pictures).
  final Point2 point;

  /// Unit direction of the knife's long axis in the image, from the entry
  /// towards the handle.
  final Point2 axis;

  /// How many pixels were taken to be the knife (steel, not shadow).
  final int knifePixels;
}

/// Finds where a new knife's blade went into the board. Implementations can be
/// swapped (geometry now; a trained model later) behind this interface.
abstract interface class EntryPointEstimator {
  EntryEstimate? estimate(RgbImage before, RgbImage after, TargetCalibration calibration);
}

/// Geometry first (D1, option A):
/// 1. Pixels whose colour changed by more than [threshold] (largest channel
///    difference) near the target form shapes; take the largest that touches
///    the target.
/// 2. Keep its **steel** pixels: grey (saturation below [steelSaturation]).
///    A knife's shadow is also "new", starts at the entry point and would
///    drag the estimate along it, but it keeps the board's own hue (red or
///    wood), just darker.
/// 3. The steel pixels' principal axis is the knife's line; one end is the
///    blade's entry, the other the handle's end.
/// 4. The knife sticks out of the board towards the thrower (roughly along
///    the board's normal, ± its pitch and yaw). In the image the normal points
///    towards the board's **far** side, which the calibration shows: a tilted
///    circle's centre appears offset from its ellipse's centre towards the
///    far side, so (bull centre − outer centre) points "out of the board".
///    The handle end is that way; the entry is the other end (the 2nd
///    percentile along the axis, ignoring stray pixels).
class GeometricEntryEstimator implements EntryPointEstimator {
  GeometricEntryEstimator({this.threshold = 20, this.steelSaturation = 0.3, this.searchMargin = 1.5});

  final int threshold;
  final double steelSaturation;
  final double searchMargin;

  @override
  EntryEstimate? estimate(RgbImage before, RgbImage after, TargetCalibration calibration) {
    final scale = after.width / calibration.imageWidth;
    final outer = calibration.outer.rescaled(scale);
    final blob = _largestNewShape(before, after, outer);
    if (blob == null || blob.length < 6) return null;

    // 2. Steel only (falls back to the whole shape if too little is grey,
    // e.g. a knife lit red by the board).
    final steel = _largestComponent(
      {for (final i in blob) if (_isSteel(after, i)) i},
      after.width,
    );
    final knife = steel.length >= math.max(6, blob.length * 0.25) ? steel : blob;

    // 3. Principal axis.
    var mx = 0.0, my = 0.0;
    for (final i in knife) {
      mx += i % after.width;
      my += i ~/ after.width;
    }
    mx /= knife.length;
    my /= knife.length;
    var sxx = 0.0, syy = 0.0, sxy = 0.0;
    for (final i in knife) {
      final dx = i % after.width - mx, dy = i ~/ after.width - my;
      sxx += dx * dx;
      syy += dy * dy;
      sxy += dx * dy;
    }
    final angle = 0.5 * math.atan2(2 * sxy, sxx - syy);
    var vx = math.cos(angle), vy = math.sin(angle);

    // 4. Point the axis "out of the board" (towards the handle).
    final out = outwardDirection(calibration);
    if (vx * out.x + vy * out.y < 0) {
      vx = -vx;
      vy = -vy;
    }
    final along = [for (final i in knife) (i % after.width - mx) * vx + (i ~/ after.width - my) * vy]..sort();
    final low = along[(along.length * 0.02).floor()];

    // The entry: centre of the knife's pixels at the low end, so it sits on
    // the blade's centre line rather than an edge.
    var ex = 0.0, ey = 0.0, n = 0;
    for (final i in knife) {
      final x = i % after.width, y = i ~/ after.width;
      final t = (x - mx) * vx + (y - my) * vy;
      if (t <= low + 2) {
        ex += x;
        ey += y;
        n++;
      }
    }
    final entry = n == 0 ? Point2(mx + vx * low, my + vy * low) : Point2(ex / n, ey / n);
    return EntryEstimate(
      point: entry,
      axis: Point2(vx, vy),
      knifePixels: knife.length,
    );
  }

  bool _isSteel(RgbImage img, int i) {
    final r = img.pixels[i * 3], g = img.pixels[i * 3 + 1], b = img.pixels[i * 3 + 2];
    final maxC = math.max(r, math.max(g, b)), minC = math.min(r, math.min(g, b));
    if (maxC < 35) return false;
    return (maxC - minC) / maxC < steelSaturation;
  }

  /// Changed pixels are found by **colour**, not brightness: shaded steel on
  /// red paint has almost the same brightness as the paint (the rendered
  /// ring-3 knife's blade went missing that way), but a very different colour.
  List<int>? _largestNewShape(RgbImage before, RgbImage after, Ellipse outer) {
    final w = after.width, h = after.height;
    int colourChange(int i) {
      final a = after.pixels, b = before.pixels;
      return math.max(
        (a[i * 3] - b[i * 3]).abs(),
        math.max((a[i * 3 + 1] - b[i * 3 + 1]).abs(), (a[i * 3 + 2] - b[i * 3 + 2]).abs()),
      );
    }

    final reach = outer.semiMajor * searchMargin;
    final x0 = math.max(0, (outer.cx - reach).floor()), x1 = math.min(w, (outer.cx + reach).ceil());
    final y0 = math.max(0, (outer.cy - reach).floor()), y1 = math.min(h, (outer.cy + reach).ceil());
    final changed = <int>{};
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final i = y * w + x;
        if (colourChange(i) > threshold &&
            outer.normalisedRadius(Point2(x.toDouble(), y.toDouble())) <= searchMargin) {
          changed.add(i);
        }
      }
    }
    List<int>? best;
    final seen = <int>{};
    for (final start in changed) {
      if (seen.contains(start)) continue;
      final shape = _flood(start, changed, seen, w);
      final touches = shape.any((i) => outer.normalisedRadius(Point2((i % w).toDouble(), (i ~/ w).toDouble())) <= 1.05);
      if (touches && (best == null || shape.length > best.length)) best = shape;
    }
    return best;
  }

  static List<int> _largestComponent(Set<int> pixels, int w) {
    var best = <int>[];
    final seen = <int>{};
    for (final start in pixels) {
      if (seen.contains(start)) continue;
      final shape = _flood(start, pixels, seen, w);
      if (shape.length > best.length) best = shape;
    }
    return best;
  }

  static List<int> _flood(int start, Set<int> pixels, Set<int> seen, int w) {
    final shape = <int>[start];
    seen.add(start);
    for (var k = 0; k < shape.length; k++) {
      final i = shape[k], x = i % w;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if ((x == 0 && dx < 0) || (x == w - 1 && dx > 0)) continue;
          final n = i + dy * w + dx;
          if (pixels.contains(n) && seen.add(n)) shape.add(n);
        }
      }
    }
    return shape;
  }
}

/// Unit direction in the image of "out of the board, towards the thrower":
/// from the outer ring's ellipse centre towards the bull's centre (a tilted
/// circle's centre appears shifted towards the board's far side, and a stick
/// standing out of the board leans that way in the picture). Falls back to
/// the outer ellipse's short axis when the view is nearly straight on.
Point2 outwardDirection(TargetCalibration c) {
  final bull = c.boundaries[c.boundaries.keys.reduce(math.min)]!;
  final dx = bull.cx - c.outer.cx, dy = bull.cy - c.outer.cy;
  final len = math.sqrt(dx * dx + dy * dy);
  if (len > c.outer.semiMajor * 0.005) return Point2(dx / len, dy / len);
  return Point2(-math.sin(c.outer.angle), math.cos(c.outer.angle));
}
