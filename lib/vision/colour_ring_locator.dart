import 'dart:math' as math;

import 'ellipse.dart';
import 'rgb_image.dart';
import 'target_locator.dart';

/// Finds a target painted in rings of **two alternating colours**, whatever
/// they are (red paint and bare wood on the reference photo, but equally
/// black/white or blue/yellow). The bull is colour A, then B, A, B, A outwards.
///
/// Real boards also come painted in **several colours**: Nigel's recorded
/// boards (2026-10-11) are dark bull / wood / red / wood / red and red bull /
/// wood / red / wood / dark green, small and blurred by video compression. So
/// every candidate is also read by **colour edges** ([_Reading.edges]): along
/// each ray the sharpest colour changes near where each boundary is expected,
/// whatever the colours either side. The better plausible fit wins.
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
/// 6. A tapped board none of that reads (stencilled rings painted in arcs on
///    speckled wood: Mark's boards, 2026-10-21): find the centre and size
///    from how well the rings line up round the tap, then read the edges
///    with that size fixed ([_alignedStarts]).
///
/// The outermost ring's outer edge is never used: on a log board it is the
/// irregular bark edge.
class ColourRingLocator implements TargetLocator {
  ColourRingLocator({
    required this.boundaryRadii,
    this.workingSize = 600,
    this.minWorkingSize = 420,
    this.minConfidence = 0.4,
    this.rayCount = 180,
    this.maxCandidates = 12,
    this.seed,
  });

  /// Normalised radii of the boundaries *inside* the target, centre outwards
  /// (for IKTHOF: 0.2, 0.4, 0.6, 0.8). Their order alternates A→B, B→A, …
  /// starting from the bull.
  final List<double> boundaryRadii;

  /// Longest side of the downscaled image the work is done on.
  final int workingSize;

  /// Smaller images are first enlarged to this (bilinear), so rays step
  /// between pixels: a 140 px video crop of a board (bull ~9 px) was found
  /// far more reliably at 3× (Live test, 2026-10-11).
  final int minWorkingSize;

  /// Fits agreeing with fewer rays than this are rejected. Wrong fits are
  /// weak: on the Live test recordings they scored 23–47%, right ones 46–78%.
  final double minConfidence;
  final int rayCount;

  /// How many candidate centres are tried, largest regions first.
  final int maxCandidates;

  /// Where the user says the target's centre is (a tap on the board, in the
  /// image's coordinates): tried before the colour regions' centres.
  final Point2? seed;

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
    final work = image.downscaled(workingSize).upscaled(minWorkingSize);
    final back = image.width / work.width;

    final labels = _paletteLabels(work, _paletteSize, edgeContrast * 0.75);
    final s = seed == null ? null : Point2(seed!.x / back, seed!.y / back);
    final candidates = [
      if (s != null) ...[s, ..._regionCentresNear(labels, work.width, work.height, s)],
      ..._candidateCentres(work, labels),
    ];
    if (candidates.isEmpty) return const TargetNotFound('No large single-colour area found');

    _Fit? best;
    _Fit? bestRejected;
    String? rejection;
    search:
    for (final centre in candidates) {
      for (final fit in _fitCandidate(centre, work)) {
        final problem = fit.confidence < minConfidence ? 'Rings too unclear' : _implausible(fit.ellipses);
        if (problem == null) {
          if (best == null || fit.confidence > best.confidence) best = fit;
          if (fit.confidence > 0.85) break search;
        } else if (bestRejected == null || fit.confidence > bestRejected.confidence) {
          bestRejected = fit;
          rejection = problem;
        }
      }
    }

    // A tapped board the usual search can't read (rings painted in arcs on
    // speckled wood: Mark's boards, 2026-10-21): centre and size from the
    // rings' alignment around the tap ([_alignedStarts]), then the edge
    // reading from there. Only from a tap: tried without one (from the
    // picture's middle) on the Live test's board 2, it turned frames the
    // usual search couldn't read into near misses (a ring 10–20% off).
    if (best == null && s != null) {
      for (final start in _alignedStarts(s, work)) {
        // The edge reading needs only the size, not the ring colours.
        const none = _Rgb(0, 0, 0);
        final fit = _fitReading(start.centre, work, _Colours(none, none, start.outerRadius), _Reading.edges,
            fixedScale: true);
        if (fit != null) {
          // A tapped board fills a fair share of the window searched round
          // the tap (Mark's middle board ~29%, the Quick draw boards ~19%);
          // grass under a tap made a 6% one, 2026-10-21.
          // And a bull under [_minBullRadius] is speckle that happens to
          // look like rings (edges are measured over ~8–16% of the bull's
          // radius). Only here: the usual search keeps small, distant boards
          // (a rejected small fit still guides [CoarseToFineLocator]).
          final outerRadius = fit.ellipses[boundaryRadii.last]!.semiMajor / boundaryRadii.last;
          final problem = fit.confidence < minConfidence
              ? 'Rings too unclear'
              : outerRadius < math.min(work.width, work.height) * _alignMinShare ||
                      fit.ellipses[boundaryRadii.first]!.semiMajor < _minBullRadius
                  ? 'Target too small'
                  : _implausible(fit.ellipses);
          if (problem == null) {
            if (best == null || fit.confidence > best.confidence) best = fit;
          } else if (bestRejected == null || fit.confidence > bestRejected.confidence) {
            bestRejected = fit;
            rejection = problem;
          }
        }
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

  /// Centres of the largest single-colour regions after palette reduction
  /// ([labels]), biggest first, with near-duplicates (a ring and the bull
  /// inside it) merged.
  List<Point2> _candidateCentres(RgbImage img, List<int> labels) {
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

  /// The fits from [start] under each reading of the rings.
  List<_Fit> _fitCandidate(Point2 start, RgbImage img) {
    final colours = _learnColours(start, img);
    if (colours == null) return const [];
    return [
      for (final reading in _Reading.values)
        ?_fitReading(start, img, colours, reading),
    ];
  }

  /// Fits from [start], then re-centres on the fit and fits again, up to
  /// three times. The expected sizes stay those from the bull's edge: taking
  /// them from a fit let a wrong one drift further out each pass. Returns the
  /// best plausible pass (re-centring can make a good fit worse), else the
  /// last.
  _Fit? _fitReading(Point2 start, RgbImage img, _Colours colours, _Reading reading, {bool fixedScale = false}) {
    var centre = start;
    _Fit? last, bestPlausible;
    for (var pass = 0; pass < 3; pass++) {
      final next = reading == _Reading.twoColour
          ? _fitFrom(centre, img, colours)
          : _fitPoints(_edgePoints(centre, img, colours.outerRadius, fixedScale: fixedScale), centre);
      if (next == null) break;
      last = next;
      if (_implausible(next.ellipses) == null && (bestPlausible == null || next.confidence > bestPlausible.confidence)) {
        bestPlausible = next;
      }
      final e = next.ellipses[boundaryRadii[boundaryRadii.length ~/ 2]]!;
      centre = Point2(e.cx, e.cy);
    }
    return bestPlausible ?? last;
  }

  /// Where a tapped board's rings may centre, and their size, from the rings'
  /// alignment: from the true centre every ring edge is at one distance all
  /// round, so the colour change averaged over every direction, by distance
  /// ([_radialProfile]), has sharp peaks; from a little off it smears, and
  /// speckle never lines up (gaps only lower a peak). Centres within
  /// [_alignReach] of the image's shorter side around [tap] are scored by
  /// their profile's peaks (on a copy shrunk to ~[_alignSize] px, for
  /// speed); the [_alignStarts] best, each with the bull radius whose
  /// multiples (the boundaries' ratios: IKTHOF 1, 2, 3, 4) land on its
  /// strongest peaks.
  List<({Point2 centre, double outerRadius})> _alignedStarts(Point2 tap, RgbImage img) {
    final f = math.min(1.0, _alignSize / math.max(img.width, img.height));
    final small = f < 1 ? img.downscaled(_alignSize) : img;
    final k = small.width / img.width;
    final t = Point2(tap.x * k, tap.y * k);
    final maxT = (math.min(small.width, small.height) * 0.5).floor();
    final reach = math.min(small.width, small.height) * _alignReach;
    double sharpness(List<double> profile) {
      final sorted = [...profile]..sort();
      return sorted.reversed.take(6).fold(0.0, (a, b) => a + b);
    }

    // A coarse grid round the tap, then a finer one round each of its
    // [_alignStarts] best points (apart from each other).
    final coarse = reach / 6;
    final scored = <(Point2, double)>[
      for (var dy = -reach; dy <= reach + 1e-9; dy += coarse)
        for (var dx = -reach; dx <= reach + 1e-9; dx += coarse)
          () {
            final c = Point2(t.x + dx, t.y + dy);
            return (c, sharpness(_radialProfile(c, small, maxT, rays: 72)));
          }(),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final picked = <Point2>[];
    for (final (c, _) in scored) {
      if (picked.length == _alignStarts) break;
      if (picked.any((p) => _dist(p, c) < coarse * 1.5)) continue;
      picked.add(c);
    }
    return [for (final around in picked) ?_refinedStart(around, small, maxT, coarse / 3, k, sharpness)];
  }

  static double _dist(Point2 a, Point2 b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  /// [_alignedStarts]: the sharpest centre on a fine grid round [around] (on
  /// the shrunk copy [small], [k] of the original), and its size.
  ({Point2 centre, double outerRadius})? _refinedStart(
      Point2 around, RgbImage small, int maxT, double step, double k, double Function(List<double>) sharpness) {
    Point2? best;
    var bestScore = 0.0;
    List<double>? bestProfile;
    for (var dy = -step * 3; dy <= step * 3 + 1e-9; dy += step) {
      for (var dx = -step * 3; dx <= step * 3 + 1e-9; dx += step) {
        final c = Point2(around.x + dx, around.y + dy);
        final profile = _radialProfile(c, small, maxT, rays: 72);
        final score = sharpness(profile);
        if (score > bestScore) {
          bestScore = score;
          best = c;
          bestProfile = profile;
        }
      }
    }
    if (best == null || bestProfile == null) return null;
    final ratios = [for (final r in boundaryRadii) r / boundaryRadii.first];
    double? bestBull;
    var bestFit = 0.0;
    for (var bull = 3.0; bull * ratios.last * 1.1 <= maxT; bull += 0.25) {
      var score = 0.0;
      for (final m in ratios) {
        var peak = 0.0;
        for (var i = (m * bull * 0.93).floor(); i <= (m * bull * 1.07).ceil() && i <= maxT; i++) {
          peak = math.max(peak, bestProfile[i]);
        }
        score += peak;
      }
      if (score > bestFit) {
        bestFit = score;
        bestBull = bull;
      }
    }
    if (bestBull == null) return null;
    return (centre: Point2(best.x / k, best.y / k), outerRadius: bestBull / k / boundaryRadii.first);
  }

  /// See [_alignedStarts]; [_alignMinShare]: the least outer radius a
  /// fallback fit may have, as a share of the window's shorter side.
  static const _alignSize = 360;
  static const _alignReach = 0.08;
  static const _alignStarts = 3;
  static const _alignMinShare = 0.1;

  /// The colour change along [rays] rays from [centre], at each distance up
  /// to [maxT], averaged over the rays (measured as [_edgePoints] does, over
  /// a couple of pixels each side).
  static List<double> _radialProfile(Point2 centre, RgbImage img, int maxT, {required int rays}) {
    final profile = List<double>.filled(maxT + 1, 0);
    const reach = 2;
    for (var i = 0; i < rays; i++) {
      final theta = 2 * math.pi * i / rays;
      final dx = math.cos(theta), dy = math.sin(theta);
      final samples = <_Rgb?>[
        for (var t = 0; t <= maxT + 2 * reach; t++)
          () {
            final x = (centre.x + dx * t).round(), y = (centre.y + dy * t).round();
            return img.contains(x, y) ? _rgbAt(img, x, y) : null;
          }(),
      ];
      for (var t = 2 * reach; t <= maxT; t++) {
        final b1 = samples[t - reach], b2 = samples[t - 2 * reach], a1 = samples[t + reach], a2 = samples[t + 2 * reach];
        if (b1 == null || b2 == null || a1 == null || a2 == null) continue;
        profile[t] += _Rgb.mean(a1, a2).distanceTo(_Rgb.mean(b1, b2)) / rays;
      }
    }
    return profile;
  }

  /// Boundary points from colour edges, whatever the colours:
  /// 1. Along each ray, the colour change at each step: the colour a little
  ///    beyond vs a little before (~8–16% of the bull radius each way, so
  ///    the measure scales with the board and ignores fine grain). Its local
  ///    peaks of at least half [edgeContrast] are edges.
  /// 2. The ray's strongest edge between 0.6 and 1.5 × the expected bull
  ///    radius is the bull's edge (the first could be texture or a knife
  ///    inside the bull).
  /// 3. Each further boundary is the strongest edge within ±[_ratioSlack] of
  ///    its expected distance **in bull radii along the same ray** (IKTHOF:
  ///    2, 3, 4), beyond the previous one. Measuring from the ray's own bull
  ///    edge cancels perspective, which scales a whole ray. Nigel's recorded
  ///    boards measure 1.94, 2.94–3.0 and 3.82.
  Map<double, List<Point2>> _edgePoints(Point2 centre, RgbImage img, double outerRadius, {bool fixedScale = false}) {
    final points = {for (final r in boundaryRadii) r: <Point2>[]};
    final bullRadius = outerRadius * boundaryRadii.first;
    final maxT = (outerRadius * 1.3).ceil();
    final reach = math.max(1, (bullRadius * 0.08).round());
    for (var i = 0; i < rayCount; i++) {
      final theta = 2 * math.pi * i / rayCount;
      final dx = math.cos(theta), dy = math.sin(theta);
      final samples = <_Rgb?>[
        for (var t = 0; t <= maxT + 2 * reach; t++)
          () {
            final x = (centre.x + dx * t).round(), y = (centre.y + dy * t).round();
            return img.contains(x, y) ? _rgbAt(img, x, y) : null;
          }(),
      ];
      final strength = List<double>.filled(samples.length, 0);
      for (var t = 2 * reach; t + 2 * reach < samples.length; t++) {
        final b1 = samples[t - reach], b2 = samples[t - 2 * reach], a1 = samples[t + reach], a2 = samples[t + 2 * reach];
        if (b1 == null || b2 == null || a1 == null || a2 == null) continue;
        strength[t] = _Rgb.mean(a1, a2).distanceTo(_Rgb.mean(b1, b2));
      }
      final edges = [
        for (var t = 1; t + 1 < samples.length; t++)
          if (strength[t] >= edgeContrast / 2 && strength[t] >= strength[t - 1] && strength[t] > strength[t + 1]) t,
      ];
      int? strongest(bool Function(int t) within) {
        int? best;
        for (final t in edges) {
          if (within(t) && (best == null || strength[t] > strength[best])) best = t;
        }
        return best;
      }

      final bull = strongest((t) => t >= bullRadius * 0.6 && t <= bullRadius * 1.5);
      if (bull == null && !fixedScale) continue;
      if (bull != null) points[boundaryRadii.first]!.add(Point2(centre.x + dx * bull, centre.y + dy * bull));
      var after = bull ?? 0;
      for (var k = 1; k < boundaryRadii.length; k++) {
        // [fixedScale]: the board's size is known ([_alignedStarts]), so every
        // ray measures from it rather than its own bull edge, which on a
        // sprayed, speckled bull is too noisy to anchor on.
        final expected = (fixedScale ? bullRadius : bull!) * boundaryRadii[k] / boundaryRadii.first;
        final next = strongest(
            (t) => t > after && t >= expected * (1 - _ratioSlack) && t <= expected * (1 + _ratioSlack));
        if (next == null) continue;
        points[boundaryRadii[k]]!.add(Point2(centre.x + dx * next, centre.y + dy * next));
        after = next;
      }
    }
    return points;
  }

  /// How far (as a fraction) a boundary may sit from its expected distance in
  /// bull radii, reading edges.
  static const _ratioSlack = 0.15;

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

    return _fitPoints(points, centre);
  }

  /// One ellipse per boundary from its points (RANSAC); null if any fails.
  /// Confidence: the share of rays that agree with each fitted boundary.
  ///
  /// A single boundary can be dragged off centre by clutter on a few rays
  /// (Live test board 2 at full resolution, 2026-10-12: the hook and stand
  /// pulled its outer boundary 10 px off). Rings are near-concentric and in
  /// proportion, so on a face-on board (or when the fit is rejected because
  /// the centres disagree) a boundary whose centre strays more than
  /// [_strayCentre] × its size from the others' is refitted from only its
  /// points within ±[_predictedSlack] of where the steadiest other boundary
  /// (scaled) puts it.
  _Fit? _fitPoints(Map<double, List<Point2>> points, Point2 centre) {
    final ellipses = <double, Ellipse>{};
    final inliers = <double, List<Point2>>{};
    for (final r in boundaryRadii) {
      final fitted = fitEllipseRansac(points[r]!);
      if (fitted == null) return null;
      ellipses[r] = fitted.ellipse;
      inliers[r] = fitted.inliers;
    }

    double median(Iterable<double> values) {
      final sorted = values.toList()..sort();
      return sorted[sorted.length ~/ 2];
    }

    final mx = median(ellipses.values.map((e) => e.cx)), my = median(ellipses.values.map((e) => e.cy));
    double stray(double r) => math.sqrt(math.pow(ellipses[r]!.cx - mx, 2) + math.pow(ellipses[r]!.cy - my, 2));
    // A tilted board's ring centres differ a little anyway (perspective), and
    // that's kept: there this is only a rescue. Face on (the outer boundary
    // nearly round), the centres should agree.
    final outer = ellipses[boundaryRadii.last]!;
    final faceOn = outer.semiMinor >= 0.9 * outer.semiMajor;
    for (final r in faceOn || _implausible(ellipses) == _centresDisagree ? boundaryRadii : const <double>[]) {
      if (stray(r) <= ellipses[r]!.semiMajor * _strayCentre) continue;
      final steadiest = boundaryRadii.where((k) => k != r).reduce((a, b) => stray(a) <= stray(b) ? a : b);
      final predicted = ellipses[steadiest]!.scaled(r / steadiest);
      final near = [for (final p in points[r]!) if ((predicted.normalisedRadius(p) - 1).abs() <= _predictedSlack) p];
      final refitted = fitEllipseRansac(near);
      if (refitted == null) continue;
      ellipses[r] = refitted.ellipse;
      inliers[r] = refitted.inliers;
    }
    final agreed = inliers.values.fold(0, (sum, list) => sum + list.length);
    return _Fit(ellipses, inliers, agreed / (rayCount * boundaryRadii.length));
  }

  /// See [_fitPoints].
  static const _strayCentre = 0.05;

  /// The tap fallback's least bull radius, in working-image pixels.
  static const _minBullRadius = 6.0;
  static const _centresDisagree = 'Ring centres disagree';
  static const _predictedSlack = 0.12;

  /// The centres of the single-colour regions under and just around [seed]
  /// (a tap): a tap rarely lands on the board's exact centre, but the bull, or
  /// the ring it lands in, is centred on it, and fits only start well from
  /// near the centre (the Quick draw clip, 2026-10-14: a tap 5–10 px off
  /// found the green and red board on 8–14 of 16 frames). A region over a
  /// quarter of the picture is background, not a ring.
  static List<Point2> _regionCentresNear(List<int> labels, int w, int h, Point2 seed) {
    final reach = math.max(2, (math.min(w, h) * 0.01).round());
    final centres = <Point2>[];
    final seen = List<bool>.filled(labels.length, false);
    for (final (dx, dy) in [(0, 0), (reach, 0), (-reach, 0), (0, reach), (0, -reach)]) {
      final x = seed.x.round() + dx, y = seed.y.round() + dy;
      if (x < 0 || y < 0 || x >= w || y >= h || seen[y * w + x]) continue;
      final region = _regionAt(labels, w, h, x, y, seen, maxSize: w * h ~/ 4);
      if (region != null) centres.add(Point2(region.cx, region.cy));
    }
    return centres;
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
      if (centreGap > outer.semiMajor * 0.1) return _centresDisagree;
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

  static _Rgb mean(_Rgb a, _Rgb b) => _Rgb((a.r + b.r) ~/ 2, (a.g + b.g) ~/ 2, (a.b + b.b) ~/ 2);

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

/// How a candidate's ring boundaries are found.
enum _Reading {
  /// Samples classed as the bull's colour (A) or the next ring's (B); the
  /// boundaries are where the A/B runs change.
  twoColour,

  /// The boundaries are the sharpest colour changes near where each is
  /// expected, whatever the colours.
  edges,
}

class _Colours {
  _Colours(this.a, this.b, this.outerRadius);

  final _Rgb a;
  final _Rgb b;

  /// Rough pixel radius of the target's outer edge, along its long axis.
  final double outerRadius;
}

/// The connected region of [labels] containing ([x], [y]), marking it in
/// [seen]; null if it grows beyond [maxSize].
_Region? _regionAt(List<int> labels, int w, int h, int x, int y, List<bool> seen, {required int maxSize}) {
  final colour = labels[y * w + x];
  var size = 0, sx = 0.0, sy = 0.0;
  final stack = [y * w + x];
  seen[y * w + x] = true;
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    final px = i % w, py = i ~/ w;
    if (++size > maxSize) return null;
    sx += px;
    sy += py;
    for (final n in [if (px > 0) i - 1, if (px < w - 1) i + 1, if (py > 0) i - w, if (py < h - 1) i + w]) {
      if (!seen[n] && labels[n] == colour) {
        seen[n] = true;
        stack.add(n);
      }
    }
  }
  return _Region(size, sx / size, sy / size);
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
