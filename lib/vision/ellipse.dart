import 'dart:math' as math;

/// A 2D point in image pixels.
class Point2 {
  const Point2(this.x, this.y);

  final double x;
  final double y;

  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// An ellipse in image pixels: centre, semi-axes and rotation of the first
/// axis ([semiMajor]'s direction) from the x axis, in radians.
class Ellipse {
  const Ellipse({
    required this.cx,
    required this.cy,
    required this.semiMajor,
    required this.semiMinor,
    required this.angle,
  });

  final double cx;
  final double cy;
  final double semiMajor;
  final double semiMinor;
  final double angle;

  /// Point on the ellipse at parameter [t] (radians).
  Point2 pointAt(double t) {
    final c = math.cos(angle), s = math.sin(angle);
    final x = semiMajor * math.cos(t), y = semiMinor * math.sin(t);
    return Point2(cx + x * c - y * s, cy + x * s + y * c);
  }

  /// 1 on the ellipse, < 1 inside, > 1 outside (scaled radial distance).
  double normalisedRadius(Point2 p) {
    final c = math.cos(angle), s = math.sin(angle);
    final dx = p.x - cx, dy = p.y - cy;
    final u = (dx * c + dy * s) / semiMajor;
    final v = (-dx * s + dy * c) / semiMinor;
    return math.sqrt(u * u + v * v);
  }

  /// This ellipse scaled by [factor] about its own centre.
  Ellipse scaled(double factor) => Ellipse(
        cx: cx,
        cy: cy,
        semiMajor: semiMajor * factor,
        semiMinor: semiMinor * factor,
        angle: angle,
      );

  /// This ellipse moved by ([dx], [dy]).
  Ellipse translated(double dx, double dy) =>
      Ellipse(cx: cx + dx, cy: cy + dy, semiMajor: semiMajor, semiMinor: semiMinor, angle: angle);

  /// This ellipse with every coordinate multiplied by [factor] (for mapping
  /// between a downscaled working image and the original).
  Ellipse rescaled(double factor) => Ellipse(
        cx: cx * factor,
        cy: cy * factor,
        semiMajor: semiMajor * factor,
        semiMinor: semiMinor * factor,
        angle: angle,
      );

  @override
  String toString() => 'Ellipse(centre (${cx.toStringAsFixed(1)}, ${cy.toStringAsFixed(1)}), '
      'axes ${semiMajor.toStringAsFixed(1)} × ${semiMinor.toStringAsFixed(1)}, '
      '${(angle * 180 / math.pi).toStringAsFixed(1)}°)';
}

/// Least-squares ellipse through [points] (Halíř & Flusser's numerically
/// stable form of Fitzgibbon's direct fit). Returns null if the points don't
/// determine an ellipse (fewer than 6, or degenerate).
Ellipse? fitEllipse(List<Point2> points) {
  if (points.length < 6) return null;

  // Centre and scale the points for numerical stability.
  var mx = 0.0, my = 0.0;
  for (final p in points) {
    mx += p.x;
    my += p.y;
  }
  mx /= points.length;
  my /= points.length;
  var spread = 0.0;
  for (final p in points) {
    spread += (p.x - mx).abs() + (p.y - my).abs();
  }
  spread /= points.length;
  if (spread == 0) return null;

  // Scatter matrices: S1 = D1ᵀD1, S2 = D1ᵀD2, S3 = D2ᵀD2, where
  // D1 rows are (x², xy, y²) and D2 rows are (x, y, 1).
  final s1 = List.generate(3, (_) => List.filled(3, 0.0));
  final s2 = List.generate(3, (_) => List.filled(3, 0.0));
  final s3 = List.generate(3, (_) => List.filled(3, 0.0));
  for (final p in points) {
    final x = (p.x - mx) / spread, y = (p.y - my) / spread;
    final d1 = [x * x, x * y, y * y];
    final d2 = [x, y, 1.0];
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        s1[i][j] += d1[i] * d1[j];
        s2[i][j] += d1[i] * d2[j];
        s3[i][j] += d2[i] * d2[j];
      }
    }
  }

  final s3inv = _invert3(s3);
  if (s3inv == null) return null;
  // T = -S3⁻¹ S2ᵀ; M = S1 + S2 T.
  final s2t = _transpose3(s2);
  final t = _scale3(_mul3(s3inv, s2t), -1);
  final m = _add3(s1, _mul3(s2, t));
  // Premultiply by C1⁻¹, where C1 = [[0,0,2],[0,-1,0],[2,0,0]].
  final mc = [
    [m[2][0] / 2, m[2][1] / 2, m[2][2] / 2],
    [-m[1][0], -m[1][1], -m[1][2]],
    [m[0][0] / 2, m[0][1] / 2, m[0][2] / 2],
  ];

  // Of mc's eigenvectors, the ellipse is the one with 4ac − b² > 0.
  List<double>? a1;
  for (final lambda in _realEigenvalues3(mc)) {
    final v = _nullVector3(mc, lambda);
    if (v == null) continue;
    if (4 * v[0] * v[2] - v[1] * v[1] > 0) {
      a1 = v;
      break;
    }
  }
  if (a1 == null) return null;
  final a2 = [
    t[0][0] * a1[0] + t[0][1] * a1[1] + t[0][2] * a1[2],
    t[1][0] * a1[0] + t[1][1] * a1[1] + t[1][2] * a1[2],
    t[2][0] * a1[0] + t[2][1] * a1[1] + t[2][2] * a1[2],
  ];

  final e = _conicToEllipse(a1[0], a1[1], a1[2], a2[0], a2[1], a2[2]);
  if (e == null) return null;
  return Ellipse(
    cx: e.cx * spread + mx,
    cy: e.cy * spread + my,
    semiMajor: e.semiMajor * spread,
    semiMinor: e.semiMinor * spread,
    angle: e.angle,
  );
}

/// Fits an ellipse robustly: repeatedly fits random 6-point samples, keeps the
/// fit most points agree with (within [tolerance] in normalised radius), then
/// refits on those inliers. Deterministic for a given [seed].
({Ellipse ellipse, List<Point2> inliers})? fitEllipseRansac(
  List<Point2> points, {
  double tolerance = 0.04,
  int iterations = 200,
  int seed = 1,
}) {
  if (points.length < 6) return null;
  final random = math.Random(seed);
  Ellipse? best;
  var bestCount = 0;
  for (var i = 0; i < iterations; i++) {
    final sample = <Point2>{};
    while (sample.length < 6) {
      sample.add(points[random.nextInt(points.length)]);
    }
    final candidate = fitEllipse(sample.toList());
    if (candidate == null) continue;
    var count = 0;
    for (final p in points) {
      if ((candidate.normalisedRadius(p) - 1).abs() <= tolerance) count++;
    }
    if (count > bestCount) {
      bestCount = count;
      best = candidate;
    }
  }
  if (best == null) return null;
  final fitted = best;
  final inliers = [for (final p in points) if ((fitted.normalisedRadius(p) - 1).abs() <= tolerance) p];
  final refit = fitEllipse(inliers) ?? fitted;
  return (ellipse: refit, inliers: inliers);
}

/// Geometric form of the conic ax² + bxy + cy² + dx + ey + f = 0.
Ellipse? _conicToEllipse(double a, double b, double c, double d, double e, double f) {
  final den = b * b - 4 * a * c;
  if (den >= 0) return null;
  final cx = (2 * c * d - b * e) / den;
  final cy = (2 * a * e - b * d) / den;
  // Value of the conic at the centre.
  final f0 = a * cx * cx + b * cx * cy + c * cy * cy + d * cx + e * cy + f;
  // Eigen-decompose the quadratic part [[a, b/2], [b/2, c]].
  final mean = (a + c) / 2;
  final diff = math.sqrt(((a - c) / 2) * ((a - c) / 2) + (b / 2) * (b / 2));
  final l1 = mean - diff, l2 = mean + diff;
  final r1 = -f0 / l1, r2 = -f0 / l2;
  if (r1 <= 0 || r2 <= 0) return null;
  // Direction of eigenvector for l1 (the smaller eigenvalue → longer axis).
  final angle = 0.5 * math.atan2(b, a - c) + math.pi / 2;
  return Ellipse(cx: cx, cy: cy, semiMajor: math.sqrt(r1), semiMinor: math.sqrt(r2), angle: _wrapAngle(angle));
}

/// Wraps [angle] into [0, π): an ellipse's axis direction has no sign.
double _wrapAngle(double angle) {
  var a = angle % math.pi;
  if (a < 0) a += math.pi;
  return a;
}

List<List<double>> _mul3(List<List<double>> x, List<List<double>> y) => [
      for (var i = 0; i < 3; i++)
        [for (var j = 0; j < 3; j++) x[i][0] * y[0][j] + x[i][1] * y[1][j] + x[i][2] * y[2][j]],
    ];

List<List<double>> _add3(List<List<double>> x, List<List<double>> y) => [
      for (var i = 0; i < 3; i++) [for (var j = 0; j < 3; j++) x[i][j] + y[i][j]],
    ];

List<List<double>> _scale3(List<List<double>> x, double k) => [
      for (final row in x) [for (final v in row) v * k],
    ];

List<List<double>> _transpose3(List<List<double>> x) => [
      for (var j = 0; j < 3; j++) [for (var i = 0; i < 3; i++) x[i][j]],
    ];

List<List<double>>? _invert3(List<List<double>> m) {
  final det = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
      m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
      m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
  if (det.abs() < 1e-12) return null;
  final inv = [
    [
      m[1][1] * m[2][2] - m[1][2] * m[2][1],
      m[0][2] * m[2][1] - m[0][1] * m[2][2],
      m[0][1] * m[1][2] - m[0][2] * m[1][1],
    ],
    [
      m[1][2] * m[2][0] - m[1][0] * m[2][2],
      m[0][0] * m[2][2] - m[0][2] * m[2][0],
      m[0][2] * m[1][0] - m[0][0] * m[1][2],
    ],
    [
      m[1][0] * m[2][1] - m[1][1] * m[2][0],
      m[0][1] * m[2][0] - m[0][0] * m[2][1],
      m[0][0] * m[1][1] - m[0][1] * m[1][0],
    ],
  ];
  return _scale3(inv, 1 / det);
}

/// Real roots of the characteristic polynomial of a 3×3 matrix.
List<double> _realEigenvalues3(List<List<double>> m) {
  // det(λI − M) = λ³ + pλ² + qλ + r.
  final tr = m[0][0] + m[1][1] + m[2][2];
  final minors = (m[0][0] * m[1][1] - m[0][1] * m[1][0]) +
      (m[0][0] * m[2][2] - m[0][2] * m[2][0]) +
      (m[1][1] * m[2][2] - m[1][2] * m[2][1]);
  final det = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
      m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
      m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
  return _cubicRealRoots(-tr, minors, -det);
}

/// Real roots of λ³ + pλ² + qλ + r = 0.
List<double> _cubicRealRoots(double p, double q, double r) {
  // Depressed cubic t³ + At + B with λ = t − p/3.
  final a = q - p * p / 3;
  final b = 2 * p * p * p / 27 - p * q / 3 + r;
  final shift = -p / 3;
  final disc = b * b / 4 + a * a * a / 27;
  if (disc > 0) {
    final s = math.sqrt(disc);
    double cbrt(double v) => v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();
    return [cbrt(-b / 2 + s) + cbrt(-b / 2 - s) + shift];
  }
  if (a == 0) return [shift];
  final rho = math.sqrt(-a / 3);
  final cosArg = (-b / 2) / (rho * rho * rho);
  final theta = math.acos(cosArg.clamp(-1.0, 1.0));
  return [
    for (var k = 0; k < 3; k++) 2 * rho * math.cos((theta + 2 * math.pi * k) / 3) + shift,
  ];
}

/// A unit vector v with (M − λI)v ≈ 0, from the best cross product of two rows.
List<double>? _nullVector3(List<List<double>> m, double lambda) {
  final rows = [
    [m[0][0] - lambda, m[0][1], m[0][2]],
    [m[1][0], m[1][1] - lambda, m[1][2]],
    [m[2][0], m[2][1], m[2][2] - lambda],
  ];
  List<double> cross(List<double> u, List<double> v) =>
      [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]];
  double norm(List<double> v) => math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
  List<double>? best;
  var bestNorm = 0.0;
  for (final pair in [(0, 1), (0, 2), (1, 2)]) {
    final c = cross(rows[pair.$1], rows[pair.$2]);
    final n = norm(c);
    if (n > bestNorm) {
      bestNorm = n;
      best = c;
    }
  }
  if (best == null || bestNorm < 1e-15) return null;
  return [best[0] / bestNorm, best[1] / bestNorm, best[2] / bestNorm];
}
