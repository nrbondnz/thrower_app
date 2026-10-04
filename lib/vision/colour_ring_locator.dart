import 'dart:math' as math;

import 'ellipse.dart';
import 'rgb_image.dart';
import 'target_locator.dart';

/// Finds a target painted in alternating **red** and bare-wood rings with a red
/// bull (see docs/thrower/reference/target-example.png).
///
/// 1. Mark red pixels on a downscaled copy of the image.
/// 2. Estimate the centre from the largest red region (the outer red ring).
/// 3. Cast rays from the centre; along each, the red/not-red runs give the ring
///    boundaries in order (bull edge, then each ring edge).
/// 4. Fit an ellipse to each boundary's points with RANSAC, so rays spoiled by
///    knife handles or cuts are outvoted.
/// 5. Re-centre on the fitted ellipses and repeat once.
///
/// The outermost red ring's outer edge is never used: on a log board it is the
/// irregular bark edge.
class ColourRingLocator implements TargetLocator {
  ColourRingLocator({required this.boundaryRadii, this.workingSize = 600, this.rayCount = 180});

  /// Normalised radii of the boundaries *inside* the target, centre outwards
  /// (for IKTHOF: 0.2, 0.4, 0.6, 0.8). Their order alternates red→wood,
  /// wood→red, … starting from a red bull.
  final List<double> boundaryRadii;

  /// Longest side of the downscaled image the work is done on.
  final int workingSize;
  final int rayCount;

  @override
  TargetLocateResult locate(RgbImage image) {
    final work = image.downscaled(workingSize);
    final back = image.width / work.width;
    final red = _redMask(work);

    final region = _largestRegion(red, work.width, work.height);
    if (region == null || region.size < work.width * work.height * 0.005) {
      return const TargetNotFound('No large red area found');
    }

    var centre = Point2(region.cx, region.cy);
    final maxRadius = region.extent * 1.5;
    _Fit? fit;
    for (var pass = 0; pass < 3; pass++) {
      final next = _fitFrom(centre, work, maxRadius);
      if (next == null) break;
      fit = next;
      final e = next.ellipses[boundaryRadii[boundaryRadii.length ~/ 2]]!;
      centre = Point2(e.cx, e.cy);
    }
    if (fit == null) return const TargetNotFound('Ring edges not found');

    final problem = _implausible(fit.ellipses);
    if (problem != null) {
      return TargetNotFound(
        problem,
        attempted: {for (final e in fit.ellipses.entries) e.key: e.value.rescaled(back)},
        attemptedPoints: {
          for (final e in fit.points.entries) e.key: [for (final p in e.value) Point2(p.x * back, p.y * back)],
        },
      );
    }

    final outerBoundary = fit.ellipses[boundaryRadii.last]!;
    return TargetFound(
      boundaries: {for (final e in fit.ellipses.entries) e.key: e.value.rescaled(back)},
      outer: outerBoundary.scaled(1 / boundaryRadii.last).rescaled(back),
      confidence: fit.confidence,
      boundaryPoints: {
        for (final e in fit.points.entries) e.key: [for (final p in e.value) Point2(p.x * back, p.y * back)],
      },
    );
  }

  /// Red paint: strongly saturated, hue near 0°. On the reference photo the
  /// paint measures saturation ~0.85 at hue ~2°, while wood tinted by overspray
  /// reaches saturation ~0.45 at hue ~16°, so the thresholds sit between.
  static bool isRed(int r, int g, int b) {
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    if (maxC < 60 || maxC != r) return false;
    final saturation = (maxC - minC) / maxC;
    if (saturation < 0.6) return false;
    // Hue in degrees for a red-dominant pixel: 60 × (g − b) / (max − min).
    final hue = 60 * (g - b) / (maxC - minC);
    return hue > -20 && hue < 12;
  }

  /// Bare wood: light, warm, moderately saturated. Anything that is neither
  /// red nor wood (handles, shadows, slots, bark, grass) is "other".
  static bool isWood(int r, int g, int b) {
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    if (maxC < 115 || maxC != r || maxC == minC) return false;
    final saturation = (maxC - minC) / maxC;
    if (saturation < 0.12 || saturation >= 0.6) return false;
    final hue = 60 * (g - b) / (maxC - minC);
    return hue >= 5 && hue <= 50;
  }

  List<bool> _redMask(RgbImage img) => [
        for (var y = 0; y < img.height; y++)
          for (var x = 0; x < img.width; x++) isRed(img.red(x, y), img.green(x, y), img.blue(x, y)),
      ];

  _Fit? _fitFrom(Point2 centre, RgbImage img, double maxRadius) {
    /// true = red, false = wood, null = other (a gap).
    bool? classAt(double x, double y) {
      final xi = x.round(), yi = y.round();
      if (!img.contains(xi, yi)) return null;
      final r = img.red(xi, yi), g = img.green(xi, yi), b = img.blue(xi, yi);
      if (isRed(r, g, b)) return true;
      if (isWood(r, g, b)) return false;
      return null;
    }

    final points = {for (final r in boundaryRadii) r: <Point2>[]};
    final minRun = math.max(2.0, maxRadius * 0.015);
    final window = math.max(1, (maxRadius * 0.01).round());
    // An edge hidden in a gap wider than this (e.g. under a handle) is skipped.
    final maxGap = window * 3 + 2;
    for (var i = 0; i < rayCount; i++) {
      final theta = 2 * math.pi * i / rayCount;
      final dx = math.cos(theta), dy = math.sin(theta);
      final ts = <int>[];
      final reds = <bool>[];
      for (var t = 0; t < maxRadius; t++) {
        final c = classAt(centre.x + dx * t, centre.y + dy * t);
        if (c == null) continue;
        ts.add(t);
        reds.add(c);
      }
      final runs = _runs(_majority(reds, window), minRun);
      // Runs alternate red/wood; the first must be the red bull.
      if (runs.isEmpty || !runs.first.red) continue;
      for (var k = 0; k < boundaryRadii.length && k + 1 < runs.length; k++) {
        final before = ts[runs[k + 1].start - 1], after = ts[runs[k + 1].start];
        if (after - before > maxGap) continue;
        final t = (before + after) / 2;
        points[boundaryRadii[k]]!.add(Point2(centre.x + dx * t, centre.y + dy * t));
      }
    }

    final ellipses = <double, Ellipse>{};
    final inliers = <double, List<Point2>>{};
    var agreed = 0;
    for (final r in boundaryRadii) {
      final fitted = fitEllipseRansac(points[r]!);
      if (fitted == null) return null;
      ellipses[r] = fitted.ellipse;
      inliers[r] = fitted.inliers;
      agreed += fitted.inliers.length;
    }
    return _Fit(ellipses, inliers, agreed / (rayCount * boundaryRadii.length));
  }

  /// Each sample becomes the majority of the samples within [halfWidth] of it,
  /// so a soft, sprayed edge lands at its midpoint and specks disappear.
  static List<bool> _majority(List<bool> samples, int halfWidth) {
    final prefix = List<int>.filled(samples.length + 1, 0);
    for (var i = 0; i < samples.length; i++) {
      prefix[i + 1] = prefix[i] + (samples[i] ? 1 : 0);
    }
    return [
      for (var i = 0; i < samples.length; i++)
        () {
          final lo = math.max(0, i - halfWidth), hi = math.min(samples.length, i + halfWidth + 1);
          return (prefix[hi] - prefix[lo]) * 2 > hi - lo;
        }(),
    ];
  }

  /// Splits a red/not-red sequence into runs, merging runs shorter than
  /// [minRun] into their neighbours (specks, cuts, sprayed edges).
  static List<_Run> _runs(List<bool> samples, double minRun) {
    final raw = <_Run>[];
    for (var i = 0; i < samples.length; i++) {
      if (raw.isEmpty || raw.last.red != samples[i]) {
        raw.add(_Run(samples[i], i, i + 1));
      } else {
        raw.last.end = i + 1;
      }
    }
    final merged = <_Run>[];
    for (final run in raw) {
      if (merged.isNotEmpty && (run.length < minRun || merged.last.red == run.red)) {
        merged.last.end = run.end;
      } else {
        merged.add(run);
      }
    }
    return merged;
  }

  /// Checks the fitted ellipses look like one target: shared centre, growing
  /// outwards, sizes roughly in proportion. Hand-painted boards aren't exact
  /// (the reference photo's bull is ~0.28 of the outer edge, not 0.25), so
  /// the proportion check is loose; scoring uses the measured boundaries.
  String? _implausible(Map<double, Ellipse> ellipses) {
    final outer = ellipses[boundaryRadii.last]!;
    var previous = 0.0;
    for (final r in boundaryRadii) {
      final e = ellipses[r]!;
      final expected = outer.semiMajor * r / boundaryRadii.last;
      final centreGap = math.sqrt(math.pow(e.cx - outer.cx, 2) + math.pow(e.cy - outer.cy, 2));
      if (centreGap > outer.semiMajor * 0.1) return 'Ring centres disagree';
      if (e.semiMajor <= previous) return 'Rings out of order';
      if ((e.semiMajor - expected).abs() > expected * 0.35) return 'Ring sizes out of proportion';
      previous = e.semiMajor;
    }
    return null;
  }
}

class _Run {
  _Run(this.red, this.start, this.end);

  final bool red;
  final int start;
  int end;

  int get length => end - start;
}

class _Fit {
  _Fit(this.ellipses, this.points, this.confidence);

  final Map<double, Ellipse> ellipses;
  final Map<double, List<Point2>> points;
  final double confidence;
}

class _Region {
  _Region(this.size, this.cx, this.cy, this.extent);

  final int size;
  final double cx;
  final double cy;

  /// Half the larger side of the region's bounding box.
  final double extent;
}

/// Largest 4-connected region of true pixels in [mask].
_Region? _largestRegion(List<bool> mask, int w, int h) {
  final seen = List<bool>.filled(mask.length, false);
  _Region? best;
  final stack = <int>[];
  for (var start = 0; start < mask.length; start++) {
    if (!mask[start] || seen[start]) continue;
    var size = 0, sx = 0.0, sy = 0.0;
    var minX = w, maxX = 0, minY = h, maxY = 0;
    seen[start] = true;
    stack.add(start);
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final x = i % w, y = i ~/ w;
      size++;
      sx += x;
      sy += y;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      for (final n in [if (x > 0) i - 1, if (x < w - 1) i + 1, if (y > 0) i - w, if (y < h - 1) i + w]) {
        if (mask[n] && !seen[n]) {
          seen[n] = true;
          stack.add(n);
        }
      }
    }
    if (best == null || size > best.size) {
      best = _Region(size, sx / size, sy / size, math.max(maxX - minX, maxY - minY) / 2);
    }
  }
  return best;
}
