import 'dart:math' as math;

import 'ellipse.dart';
import 'rgb_image.dart';
import 'target_locator.dart';

/// Finds a target painted in rings of **two alternating colours**, whatever
/// they are (red paint and bare wood on the reference photo, but equally
/// black/white or blue/yellow). The bull is colour A, then B, A, B, A outwards.
///
/// 1. Reduce a downscaled copy of the image to a small palette (k-means) and
///    take the centres of the largest single-colour regions as candidate
///    target centres: the bull's region, and each ring's, centre on the target.
/// 2. For each candidate, learn the two colours: A is the colour at the
///    centre, and B is the colour just past the first edge along rays.
/// 3. Cast rays from the centre; along each, the A/B runs give the ring
///    boundaries in order (bull edge, then each ring edge). Samples near
///    neither colour (handles, shadows, slots) are gaps.
/// 4. Fit an ellipse to each boundary's points with RANSAC, so rays spoiled by
///    knife handles or cuts are outvoted. Re-centre on the fit and repeat.
/// 5. Keep the candidate whose rings pass the sanity checks with the highest
///    confidence.
///
/// The outermost ring's outer edge is never used: on a log board it is the
/// irregular bark edge.
class ColourRingLocator implements TargetLocator {
  ColourRingLocator({
    required this.boundaryRadii,
    this.workingSize = 600,
    this.rayCount = 180,
    this.maxCandidates = 12,
  });

  /// Normalised radii of the boundaries *inside* the target, centre outwards
  /// (for IKTHOF: 0.2, 0.4, 0.6, 0.8). Their order alternates A→B, B→A, …
  /// starting from the bull.
  final List<double> boundaryRadii;

  /// Longest side of the downscaled image the work is done on.
  final int workingSize;
  final int rayCount;

  /// How many candidate centres are tried, largest regions first.
  final int maxCandidates;

  /// Palette size for finding candidate regions: the two ring colours plus
  /// room for background, handles and shading.
  static const _paletteSize = 8;

  /// RGB distance that counts as "a different colour" when probing for the
  /// bull's edge, and the least the two ring colours must differ by. Sensor
  /// noise on a flat colour stays well under it (about 20 on the fixtures).
  static const edgeContrast = 60.0;

  /// A sample is classed as A or B only if it is within this fraction of the
  /// A–B distance of that colour. Blends along a soft, sprayed edge always
  /// qualify; dark handles and shadows usually don't (they become gaps).
  static const _classReach = 0.55;

  @override
  TargetLocateResult locate(RgbImage image) {
    final work = image.downscaled(workingSize);
    final back = image.width / work.width;

    final candidates = _candidateCentres(work);
    if (candidates.isEmpty) return const TargetNotFound('No large single-colour area found');

    _Fit? best;
    _Fit? bestRejected;
    String? rejection;
    for (final centre in candidates) {
      final fit = _fitCandidate(centre, work);
      if (fit == null) continue;
      final problem = _implausible(fit.ellipses);
      if (problem == null) {
        if (best == null || fit.confidence > best.confidence) best = fit;
        if (fit.confidence > 0.85) break;
      } else if (bestRejected == null || fit.confidence > bestRejected.confidence) {
        bestRejected = fit;
        rejection = problem;
      }
    }

    if (best == null) {
      if (bestRejected == null) return const TargetNotFound('No two-colour ring pattern found');
      return TargetNotFound(
        rejection!,
        attempted: {for (final e in bestRejected.ellipses.entries) e.key: e.value.rescaled(back)},
        attemptedPoints: {
          for (final e in bestRejected.points.entries)
            e.key: [for (final p in e.value) Point2(p.x * back, p.y * back)],
        },
      );
    }

    final outerBoundary = best.ellipses[boundaryRadii.last]!;
    return TargetFound(
      boundaries: {for (final e in best.ellipses.entries) e.key: e.value.rescaled(back)},
      outer: outerBoundary.scaled(1 / boundaryRadii.last).rescaled(back),
      confidence: best.confidence,
      boundaryPoints: {
        for (final e in best.points.entries) e.key: [for (final p in e.value) Point2(p.x * back, p.y * back)],
      },
    );
  }

  /// Centres of the largest single-colour regions after palette reduction,
  /// biggest first, with near-duplicates (a ring and the bull inside it) merged.
  List<Point2> _candidateCentres(RgbImage img) {
    final labels = _paletteLabels(img, _paletteSize, edgeContrast * 0.75);
    final regions = _regions(labels, img.width, img.height, (img.width * img.height * 0.001).ceil())
      ..sort((a, b) => b.size.compareTo(a.size));
    final minGap = math.max(img.width, img.height) * 0.02;
    final centres = <Point2>[];
    for (final r in regions) {
      if (centres.length == maxCandidates) break;
      if (centres.any((c) => math.sqrt(math.pow(c.x - r.cx, 2) + math.pow(c.y - r.cy, 2)) < minGap)) continue;
      centres.add(Point2(r.cx, r.cy));
    }
    return centres;
  }

  _Fit? _fitCandidate(Point2 start, RgbImage img) {
    final colours = _learnColours(start, img);
    if (colours == null) return null;
    var centre = start;
    _Fit? fit;
    for (var pass = 0; pass < 3; pass++) {
      final next = _fitFrom(centre, img, colours);
      if (next == null) break;
      fit = next;
      final e = next.ellipses[boundaryRadii[boundaryRadii.length ~/ 2]]!;
      centre = Point2(e.cx, e.cy);
    }
    return fit;
  }

  /// Learns the bull colour (A), the next ring's colour (B) and the target's
  /// rough size from rays around [centre]. Null if there's no clear edge or
  /// the two colours are too alike.
  _Colours? _learnColours(Point2 centre, RgbImage img) {
    final cx = centre.x.round(), cy = centre.y.round();
    if (!img.contains(cx, cy)) return null;
    final a0 = _rgbAt(img, cx, cy);
    const probes = 72;
    const confirm = 3;
    final edges = <double>[];
    final aSamples = <_Rgb>[], bSamples = <_Rgb>[];
    // Under an affine view, distances along a ray through the centre keep
    // their ratios, so the B ring sits at a fixed multiple of the bull's edge.
    final q = boundaryRadii.length > 1 ? boundaryRadii[1] / boundaryRadii[0] : 2.0;
    for (var i = 0; i < probes; i++) {
      final theta = 2 * math.pi * i / probes;
      final dx = math.cos(theta), dy = math.sin(theta);
      _Rgb? sample(double t) {
        final x = (centre.x + dx * t).round(), y = (centre.y + dy * t).round();
        return img.contains(x, y) ? _rgbAt(img, x, y) : null;
      }

      double? edge;
      var run = 0;
      for (var t = 1;; t++) {
        final c = sample(t.toDouble());
        if (c == null) break;
        run = c.distanceTo(a0) > edgeContrast ? run + 1 : 0;
        if (run == confirm) {
          edge = (t - confirm + 1).toDouble();
          break;
        }
      }
      if (edge == null || edge < 2) continue;
      edges.add(edge);
      for (var t = 0.0; t < edge * 0.7; t++) {
        aSamples.add(sample(t)!);
      }
      for (var t = edge * (1 + 0.25 * (q - 1)); t < edge * (1 + 0.75 * (q - 1)); t++) {
        final c = sample(t);
        if (c != null) bSamples.add(c);
      }
    }
    if (edges.length < probes / 2 || bSamples.isEmpty) return null;
    final a = _Rgb.median(aSamples), b = _Rgb.median(bSamples);
    if (a.distanceTo(b) < edgeContrast) return null;
    edges.sort();
    final longEdge = edges[(edges.length * 0.8).floor()];
    return _Colours(a, b, longEdge / boundaryRadii.first);
  }

  _Fit? _fitFrom(Point2 centre, RgbImage img, _Colours colours) {
    final reach = colours.a.distanceTo(colours.b) * _classReach;

    /// true = A, false = B, null = neither (a gap).
    bool? classAt(double x, double y) {
      final xi = x.round(), yi = y.round();
      if (!img.contains(xi, yi)) return null;
      final c = _rgbAt(img, xi, yi);
      final da = c.distanceTo(colours.a), db = c.distanceTo(colours.b);
      if (da <= db) return da <= reach ? true : null;
      return db <= reach ? false : null;
    }

    final maxRadius = colours.outerRadius * 1.3;
    final points = {for (final r in boundaryRadii) r: <Point2>[]};
    final minRun = math.max(2.0, maxRadius * 0.015);
    final window = math.max(1, (maxRadius * 0.01).round());
    // An edge hidden in a gap wider than this (e.g. under a handle) is skipped.
    final maxGap = window * 3 + 2;
    for (var i = 0; i < rayCount; i++) {
      final theta = 2 * math.pi * i / rayCount;
      final dx = math.cos(theta), dy = math.sin(theta);
      final ts = <int>[];
      final isA = <bool>[];
      for (var t = 0; t < maxRadius; t++) {
        final c = classAt(centre.x + dx * t, centre.y + dy * t);
        if (c == null) continue;
        ts.add(t);
        isA.add(c);
      }
      final runs = _runs(_majority(isA, window), minRun);
      // Runs alternate A/B; the first must be the bull (A).
      if (runs.isEmpty || !runs.first.isA) continue;
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

  /// Splits an A/B sequence into runs, merging runs shorter than
  /// [minRun] into their neighbours (specks, cuts, sprayed edges).
  static List<_Run> _runs(List<bool> samples, double minRun) {
    final raw = <_Run>[];
    for (var i = 0; i < samples.length; i++) {
      if (raw.isEmpty || raw.last.isA != samples[i]) {
        raw.add(_Run(samples[i], i, i + 1));
      } else {
        raw.last.end = i + 1;
      }
    }
    final merged = <_Run>[];
    for (final run in raw) {
      if (merged.isNotEmpty && (run.length < minRun || merged.last.isA == run.isA)) {
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
  _Run(this.isA, this.start, this.end);

  final bool isA;
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

class _Rgb {
  const _Rgb(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;

  double distanceTo(_Rgb o) {
    final dr = r - o.r, dg = g - o.g, db = b - o.b;
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  /// Per-channel median: robust to a minority of handle or shadow samples.
  static _Rgb median(List<_Rgb> samples) {
    int mid(List<int> v) => (v..sort())[v.length ~/ 2];
    return _Rgb(
      mid([for (final s in samples) s.r]),
      mid([for (final s in samples) s.g]),
      mid([for (final s in samples) s.b]),
    );
  }
}

_Rgb _rgbAt(RgbImage img, int x, int y) => _Rgb(img.red(x, y), img.green(x, y), img.blue(x, y));

class _Colours {
  _Colours(this.a, this.b, this.outerRadius);

  final _Rgb a;
  final _Rgb b;

  /// Rough pixel radius of the target's outer edge, along its long axis.
  final double outerRadius;
}

class _Region {
  _Region(this.size, this.cx, this.cy);

  final int size;
  final double cx;
  final double cy;
}

/// Labels every pixel with its nearest colour in a [k]-colour palette found by
/// k-means on a subsample. Seeded, so the result is deterministic.
List<int> _paletteLabels(RgbImage img, int k, double mergeDistance) {
  final step = math.max(1, math.sqrt(img.width * img.height / 20000).floor());
  final samples = <_Rgb>[
    for (var y = 0; y < img.height; y += step)
      for (var x = 0; x < img.width; x += step) _rgbAt(img, x, y),
  ];

  double d2(_Rgb s, List<double> c) {
    final dr = s.r - c[0], dg = s.g - c[1], db = s.b - c[2];
    return dr * dr + dg * dg + db * db;
  }

  // k-means++ seeding.
  final random = math.Random(1);
  final first = samples[random.nextInt(samples.length)];
  final centres = <List<double>>[
    [first.r.toDouble(), first.g.toDouble(), first.b.toDouble()],
  ];
  final nearest = List<double>.filled(samples.length, double.infinity);
  while (centres.length < k) {
    var total = 0.0;
    for (var i = 0; i < samples.length; i++) {
      nearest[i] = math.min(nearest[i], d2(samples[i], centres.last));
      total += nearest[i];
    }
    if (total == 0) break;
    var pick = random.nextDouble() * total;
    var chosen = samples.length - 1;
    for (var i = 0; i < samples.length; i++) {
      pick -= nearest[i];
      if (pick <= 0) {
        chosen = i;
        break;
      }
    }
    final s = samples[chosen];
    centres.add([s.r.toDouble(), s.g.toDouble(), s.b.toDouble()]);
  }

  int label(_Rgb s) {
    var best = 0;
    var bestD = double.infinity;
    for (var c = 0; c < centres.length; c++) {
      final d = d2(s, centres[c]);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return best;
  }

  for (var iteration = 0; iteration < 10; iteration++) {
    final sums = List.generate(centres.length, (_) => [0.0, 0.0, 0.0, 0.0]);
    for (final s in samples) {
      final sum = sums[label(s)];
      sum[0] += s.r;
      sum[1] += s.g;
      sum[2] += s.b;
      sum[3]++;
    }
    for (var c = 0; c < centres.length; c++) {
      if (sums[c][3] > 0) centres[c] = [sums[c][0] / sums[c][3], sums[c][1] / sums[c][3], sums[c][2] / sums[c][3]];
    }
  }

  // A flat colour with sensor noise gets split between neighbouring palette
  // entries, which would shatter its region into speckles: merge palette
  // entries closer than [mergeDistance] into one label.
  final merged = List<int>.generate(centres.length, (i) => i);
  int root(int i) => merged[i] == i ? i : merged[i] = root(merged[i]);
  for (var i = 0; i < centres.length; i++) {
    for (var j = i + 1; j < centres.length; j++) {
      final c = centres[j];
      if (d2(_Rgb(c[0].round(), c[1].round(), c[2].round()), centres[i]) < mergeDistance * mergeDistance) {
        merged[root(j)] = root(i);
      }
    }
  }

  return [
    for (var y = 0; y < img.height; y++)
      for (var x = 0; x < img.width; x++) root(label(_rgbAt(img, x, y))),
  ];
}

/// Every 4-connected same-label region of at least [minSize] pixels.
List<_Region> _regions(List<int> labels, int w, int h, int minSize) {
  final seen = List<bool>.filled(labels.length, false);
  final found = <_Region>[];
  final stack = <int>[];
  for (var start = 0; start < labels.length; start++) {
    if (seen[start]) continue;
    final colour = labels[start];
    var size = 0, sx = 0.0, sy = 0.0;
    seen[start] = true;
    stack.add(start);
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final x = i % w, y = i ~/ w;
      size++;
      sx += x;
      sy += y;
      for (final n in [if (x > 0) i - 1, if (x < w - 1) i + 1, if (y > 0) i - w, if (y < h - 1) i + w]) {
        if (!seen[n] && labels[n] == colour) {
          seen[n] = true;
          stack.add(n);
        }
      }
    }
    if (size >= minSize) found.add(_Region(size, sx / size, sy / size));
  }
  return found;
}
