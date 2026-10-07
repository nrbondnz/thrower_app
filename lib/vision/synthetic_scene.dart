import 'dart:math' as math;

import 'ellipse.dart';
import 'photo_board_texture.dart';
import 'rgb_image.dart';

/// A 3D vector (metres).
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double k) => Vec3(x * k, y * k, z * k);
  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 cross(Vec3 o) => Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(dot(this));
  Vec3 get normalised => this * (1 / length);
}

/// A knife stuck in the board.
class StuckKnife {
  const StuckKnife({
    required this.u,
    required this.v,
    this.pitchDegrees = 0,
    this.yawDegrees = 0,
  });

  /// Where the blade entered, in normalised target coordinates (centre 0,0;
  /// outer edge of the outermost scoring ring at radius 1; v up).
  final double u;
  final double v;

  /// Handle tilted up (+) or down (−) from straight out of the board, from the
  /// throw's spin.
  final double pitchDegrees;

  /// Handle tilted to the thrower's right (+) or left (−).
  final double yawDegrees;
}

/// The answer for one knife: where its blade entered, in the image.
class KnifeTruth {
  const KnifeTruth(this.knife, this.entryPixel, this.score);

  final StuckKnife knife;
  final Point2 entryPixel;
  final int score;
}

class RenderedScene {
  const RenderedScene(this.image, this.knives, this.ringEdges);

  final RgbImage image;
  final List<KnifeTruth> knives;

  /// Each ring boundary (normalised radius) projected into the image, as
  /// points around it (perspective makes them not quite ellipses).
  final Map<double, List<Point2>> ringEdges;
}

/// A photo-like 3D render of the throwing setup, with known answers.
///
/// World (metres): the board's painted face is the plane z = 0, centred on the
/// origin, facing the thrower (+z); x is the thrower's right, y up. A log slice
/// (irregular bark edge, 8 cm thick) on a three-legged stand, 1.5 m above
/// grass. Rings are sprayed in [colourA] (bull, and every other ring) and
/// [colourB] (bare wood by default), with soft edges, overspray and old knife
/// slits. Knives have an exposed steel blade and a dark handle. The sun casts
/// shadows. The camera is a phone: [cameraPosition] looking at the board's
/// centre, landscape, [horizontalFovDegrees] wide.
class SyntheticScene {
  SyntheticScene({
    this.width = 1600,
    this.height = 1200,
    this.cameraPosition = const Vec3(2.0, 0.0, 2.0),
    this.horizontalFovDegrees = 66,
    this.knives = const [],
    this.colourA = (172, 30, 24),
    this.colourB = (232, 190, 146),
    this.targetRadius = 0.25,
    this.ringRadii = const [0.2, 0.4, 0.6, 0.8, 1.0],
    this.supersample = 2,
    this.seed = 11,
    this.texture,
  });

  /// A real board's face (from a photo). When given, it replaces the generated
  /// paint, wood and bark, and sets the board's outline.
  final PhotoBoardTexture? texture;

  final int width;
  final int height;
  final Vec3 cameraPosition;
  final double horizontalFovDegrees;
  final List<StuckKnife> knives;
  final (int, int, int) colourA;
  final (int, int, int) colourB;

  /// Radius of normalised radius 1 (IKTHOF: 25 cm).
  final double targetRadius;
  final List<double> ringRadii;

  /// Rays per pixel along each axis (2 → 4 rays, smoother edges).
  final int supersample;
  final int seed;

  static const _boardRadius = 0.31;
  static const _boardThickness = 0.08;
  static const _groundY = -1.5;
  static const _bladeLength = 0.09;
  static const _handleLength = 0.13;
  static final _sun = const Vec3(-0.35, 0.65, 0.68).normalised;

  late final Vec3 _forward = (const Vec3(0, 0, 0) - cameraPosition).normalised;
  late final Vec3 _right = _forward.cross(const Vec3(0, 1, 0)).normalised;
  late final Vec3 _up = _right.cross(_forward);
  late final double _tanH = math.tan(horizontalFovDegrees * math.pi / 360);
  late final double _tanV = _tanH * height / width;
  late final double _edgePhase = math.Random(seed).nextDouble() * 6;
  late final List<_Box> _boxes = [for (final k in knives) ..._knifeBoxes(k)];
  late final List<_Rod> _legs = const [
    _Rod(Vec3(-0.17, -0.22, -0.09), Vec3(-0.62, _groundY, 0.32), 0.022),
    _Rod(Vec3(0.17, -0.22, -0.09), Vec3(0.62, _groundY, 0.32), 0.022),
    _Rod(Vec3(0, -0.2, -0.09), Vec3(0, _groundY, -0.75), 0.022),
  ];
  late final List<(double, double, double)> _cuts = () {
    final r = math.Random(seed + 1);
    return [
      for (var i = 0; i < 14; i++)
        (
          (r.nextDouble() * 2 - 1) * 0.2,
          (r.nextDouble() * 2 - 1) * 0.2,
          0.02 + r.nextDouble() * 0.04,
        ),
    ];
  }();

  RenderedScene render() {
    final img = RgbImage.blank(width, height);
    final n = supersample;
    for (var py = 0; py < height; py++) {
      for (var px = 0; px < width; px++) {
        var r = 0.0, g = 0.0, b = 0.0;
        for (var sy = 0; sy < n; sy++) {
          for (var sx = 0; sx < n; sx++) {
            final c = _trace(_ray(px + (sx + 0.5) / n, py + (sy + 0.5) / n));
            r += c.$1;
            g += c.$2;
            b += c.$3;
          }
        }
        final k = 1 / (n * n);
        img.setPixel(px, py, (r * k).round().clamp(0, 255), (g * k).round().clamp(0, 255), (b * k).round().clamp(0, 255));
      }
    }
    return RenderedScene(
      img,
      [for (final k in knives) KnifeTruth(k, project(_onBoard(k.u, k.v)), _score(k.u, k.v))],
      {
        for (final r in ringRadii.take(ringRadii.length - 1))
          r: [
            for (var i = 0; i < 72; i++)
              project(_onBoard(r * math.cos(i * math.pi / 36), r * math.sin(i * math.pi / 36))),
          ],
      },
    );
  }

  /// World point → image pixel.
  Point2 project(Vec3 p) {
    final d = p - cameraPosition;
    final z = d.dot(_forward);
    final x = d.dot(_right) / z, y = d.dot(_up) / z;
    return Point2((x / _tanH + 1) / 2 * width, (1 - y / _tanV) / 2 * height);
  }

  Vec3 _onBoard(double u, double v) => Vec3(u * targetRadius, v * targetRadius, 0);

  int _score(double u, double v) {
    final r = math.sqrt(u * u + v * v);
    final ring = ringRadii.indexWhere((edge) => r <= edge);
    return ring == -1 ? 0 : ringRadii.length - ring;
  }

  ({Vec3 origin, Vec3 dir}) _ray(double px, double py) {
    final x = (2 * px / width - 1) * _tanH;
    final y = (1 - 2 * py / height) * _tanV;
    return (origin: cameraPosition, dir: (_forward + _right * x + _up * y).normalised);
  }

  /// Board edge (metres) in direction [angle].
  double _boardEdge(double angle) {
    final t = texture;
    if (t != null) return t.edgeAt(angle) * targetRadius;
    return _boardRadius * (1 + 0.035 * math.sin(5 * angle + _edgePhase) + 0.015 * math.sin(11 * angle + 1.3));
  }

  // --- Tracing -------------------------------------------------------------

  (double, double, double) _trace(({Vec3 origin, Vec3 dir}) ray) {
    final hit = _nearest(ray.origin, ray.dir);
    if (hit == null) return _sky(ray.dir);
    final p = ray.origin + ray.dir * hit.t;
    final lit = _inShadow(p + hit.normal * 0.0005) ? 0.0 : math.max(0.0, hit.normal.dot(_sun));
    var light = 0.42 + 0.58 * lit;
    // A photo face already carries its own lighting: only shadows darken it.
    if (texture != null && hit.kind == _Kind.face) light /= 0.42 + 0.58 * _sun.z;
    final base = switch (hit.kind) {
      _Kind.face => _faceColour(p),
      _Kind.bark => _bark(p),
      _Kind.blade => const (178.0, 182.0, 188.0),
      _Kind.handle => _handle(p, hit),
      _Kind.leg => const (214.0, 190.0, 150.0),
      _Kind.ground => _grass(p),
    };
    // A little shine on the steel.
    final shine = hit.kind == _Kind.blade ? 60 * math.pow(math.max(0.0, hit.normal.dot(_sun)), 8) : 0.0;
    return (base.$1 * light + shine, base.$2 * light + shine, base.$3 * light + shine);
  }

  _Hit? _nearest(Vec3 o, Vec3 d) {
    _Hit? best;
    void consider(_Hit? h) {
      if (h != null && h.t > 1e-6 && (best == null || h.t < best!.t)) best = h;
    }

    consider(_face(o, d));
    consider(_logSide(o, d));
    for (final box in _boxes) {
      consider(box.intersect(o, d));
    }
    for (final leg in _legs) {
      consider(leg.intersect(o, d));
    }
    if (d.y < 0) {
      final t = (_groundY - o.y) / d.y;
      consider(_Hit(t, const Vec3(0, 1, 0), _Kind.ground));
    }
    return best;
  }

  bool _inShadow(Vec3 p) {
    final h = _nearest(p, _sun);
    return h != null && h.kind != _Kind.ground;
  }

  _Hit? _face(Vec3 o, Vec3 d) {
    if (d.z.abs() < 1e-9) return null;
    final t = -o.z / d.z;
    final p = o + d * t;
    final r = math.sqrt(p.x * p.x + p.y * p.y);
    final edge = _boardEdge(math.atan2(p.y, p.x));
    if (r > edge) return null;
    // Generated boards: the outermost centimetre is bark. (A photo has its own.)
    final bark = texture == null && r > edge - 0.012;
    return _Hit(t, Vec3(0, 0, d.z < 0 ? 1 : -1), bark ? _Kind.bark : _Kind.face);
  }

  /// The log's bark side, between the face (z = 0) and the back. The edge is
  /// irregular, so intersect a cylinder and refine its radius to the edge at
  /// the hit's angle a few times.
  _Hit? _logSide(Vec3 o, Vec3 d) {
    final a = d.x * d.x + d.y * d.y;
    if (a < 1e-12) return null;
    final b = 2 * (o.x * d.x + o.y * d.y);
    var radius = texture == null ? _boardRadius : texture!.maxEdge * targetRadius;
    double? t;
    for (var i = 0; i < 4; i++) {
      final c = o.x * o.x + o.y * o.y - radius * radius;
      final disc = b * b - 4 * a * c;
      if (disc < 0) return null;
      t = (-b - math.sqrt(disc)) / (2 * a);
      final p = o + d * t;
      radius = _boardEdge(math.atan2(p.y, p.x));
    }
    final p = o + d * t!;
    if (t <= 0 || p.z > 0 || p.z < -_boardThickness) return null;
    final angle = math.atan2(p.y, p.x);
    return _Hit(t, Vec3(math.cos(angle), math.sin(angle), 0), _Kind.bark);
  }

  // --- Materials -----------------------------------------------------------

  (double, double, double) _faceColour(Vec3 p) {
    final t = texture;
    if (t != null) {
      var colour = t.colourAt(p.x / targetRadius, p.y / targetRadius);
      for (final k in knives) {
        final e = _onBoard(k.u, k.v);
        if ((p.x - e.x).abs() < 0.0015 && (p.y - e.y).abs() < 0.014) colour = (30.0, 20.0, 15.0);
      }
      return colour;
    }
    final r = math.sqrt(p.x * p.x + p.y * p.y);
    final rn = r / targetRadius;
    // Wood: base tone with growth rings and grain.
    final growth = math.sin(r * 2 * math.pi / 0.007 + 3 * _noise(p.x * 9, p.y * 9));
    final grain = _noise(p.x * 80, p.y * 6) - 0.5;
    final woodShade = 1 + 0.05 * growth + 0.08 * grain;
    final wood = (colourB.$1 * woodShade, colourB.$2 * woodShade, colourB.$3 * woodShade);

    // Paint coverage 0..1: A on the bull and every other ring, sprayed edges.
    var paint = _paintAt(rn);
    // Overspray: streaky tint of A on B near the edges.
    if (paint < 1) {
      final streak = _noise(p.x * 140, p.y * 140);
      paint = math.max(paint, 0.35 * streak * _nearEdge(rn));
    }
    final a = (colourA.$1 * (0.92 + 0.16 * grain), colourA.$2 * 1.0, colourA.$3 * 1.0);
    var colour = _mix(wood, a, paint);

    // Old knife slits: short dark vertical cuts.
    for (final (cx, cy, len) in _cuts) {
      if ((p.x - cx).abs() < 0.0012 && (p.y - cy).abs() < len / 2) {
        colour = _mix(colour, (40.0, 25.0, 18.0), 0.85);
      }
    }
    // Slits under the stuck knives.
    for (final k in knives) {
      final e = _onBoard(k.u, k.v);
      if ((p.x - e.x).abs() < 0.0015 && (p.y - e.y).abs() < 0.014) colour = (30.0, 20.0, 15.0);
    }
    return colour;
  }

  /// How much of colour A covers normalised radius [rn] (soft sprayed edges).
  double _paintAt(double rn) {
    const soft = 0.035; // ~9 mm on a 25 cm target.
    var inA = true;
    var coverage = 0.0;
    var previous = 0.0;
    for (var i = 0; i < ringRadii.length - 1; i++) {
      final edge = ringRadii[i];
      if (rn < edge - soft) {
        coverage = inA ? 1 : 0;
        return rn - previous < soft && i > 0 ? coverage : coverage;
      }
      if (rn < edge + soft) {
        final t = (rn - (edge - soft)) / (2 * soft);
        final s = t * t * (3 - 2 * t);
        return inA ? 1 - s : s;
      }
      inA = !inA;
      previous = edge;
    }
    return inA ? 1 : 0; // The outer ring runs on to the bark.
  }

  double _nearEdge(double rn) {
    var nearest = double.infinity;
    for (final edge in ringRadii.take(ringRadii.length - 1)) {
      nearest = math.min(nearest, (rn - edge).abs());
    }
    return math.max(0.0, 1 - nearest / 0.12);
  }

  (double, double, double) _bark(Vec3 p) {
    final n = _noise(p.x * 60 + p.z * 40, p.y * 60);
    return (95 + 40 * n, 60 + 25 * n, 40 + 15 * n);
  }

  (double, double, double) _grass(Vec3 p) {
    final n = _noise(p.x * 25, p.z * 25), m = _noise(p.x * 3, p.z * 3);
    return (60 + 40 * n + 20 * m, 115 + 45 * n, 45 + 25 * n);
  }

  (double, double, double) _sky(Vec3 d) {
    final t = math.max(0.0, math.min(1.0, d.y * 3 + 0.3));
    // Distant trees near the horizon (ragged top), sky above.
    final across = math.atan2(d.x, d.z);
    final treeTop = 0.07 + 0.05 * _noise(across * 12, 0.5) + 0.02 * _noise(across * 60, 1.5);
    if (d.y < treeTop) {
      final n = 0.6 * _noise(across * 150, d.y * 150) + 0.4 * _noise(across * 30, d.y * 30);
      return (40 + 40 * n, 70 + 45 * n, 38 + 25 * n);
    }
    return _mix((190.0, 210.0, 225.0), (120.0, 160.0, 210.0), t);
  }

  (double, double, double) _handle(Vec3 p, _Hit hit) {
    // Dark handle with two light metal bands.
    final along = hit.along ?? 0;
    final band = (along > 0.30 && along < 0.36) || (along > 0.80 && along < 0.86);
    return band ? const (150.0, 150.0, 150.0) : const (42.0, 34.0, 30.0);
  }

  // --- Knife geometry ------------------------------------------------------

  List<_Box> _knifeBoxes(StuckKnife k) {
    final pitch = k.pitchDegrees * math.pi / 180, yaw = k.yawDegrees * math.pi / 180;
    final out = Vec3(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)).normalised;
    // The blade spins in a vertical plane, so its width runs up/down.
    final up = const Vec3(0, 1, 0);
    final widthAxis = (up - out * up.dot(out)).normalised;
    final thicknessAxis = out.cross(widthAxis);
    final entry = _onBoard(k.u, k.v);
    return [
      _Box(entry + out * (_bladeLength / 2), [out, widthAxis, thicknessAxis], [_bladeLength / 2, 0.013, 0.0016],
          _Kind.blade),
      _Box(entry + out * (_bladeLength + _handleLength / 2), [out, widthAxis, thicknessAxis],
          [_handleLength / 2, 0.014, 0.009], _Kind.handle),
    ];
  }

  // --- Helpers -------------------------------------------------------------

  static (double, double, double) _mix((double, double, double) a, (double, double, double) b, double t) =>
      (a.$1 + (b.$1 - a.$1) * t, a.$2 + (b.$2 - a.$2) * t, a.$3 + (b.$3 - a.$3) * t);

  /// Smooth value noise in 0..1.
  double _noise(double x, double y) {
    final xi = x.floor(), yi = y.floor();
    final fx = x - xi, fy = y - yi;
    double h(int a, int b) {
      var n = a * 374761393 + b * 668265263 + seed * 2246822519;
      n = (n ^ (n >> 13)) * 1274126177;
      return ((n ^ (n >> 16)) & 0xffff) / 0xffff;
    }

    final sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
    final top = h(xi, yi) + (h(xi + 1, yi) - h(xi, yi)) * sx;
    final bottom = h(xi, yi + 1) + (h(xi + 1, yi + 1) - h(xi, yi + 1)) * sx;
    return top + (bottom - top) * sy;
  }
}

enum _Kind { face, bark, blade, handle, leg, ground }

class _Hit {
  _Hit(this.t, this.normal, this.kind, {this.along});

  final double t;
  final Vec3 normal;
  final _Kind kind;

  /// For boxes: position along the long axis, 0 (blade end) to 1.
  final double? along;
}

/// An oriented box: centre, three unit axes and half-sizes along them.
class _Box {
  _Box(this.centre, this.axes, this.half, this.kind);

  final Vec3 centre;
  final List<Vec3> axes;
  final List<double> half;
  final _Kind kind;

  _Hit? intersect(Vec3 o, Vec3 d) {
    final rel = o - centre;
    var tMin = -double.infinity, tMax = double.infinity;
    var normalAxis = 0;
    var normalSign = 1.0;
    for (var i = 0; i < 3; i++) {
      final e = axes[i].dot(rel), f = axes[i].dot(d);
      if (f.abs() < 1e-12) {
        if (e.abs() > half[i]) return null;
        continue;
      }
      var t1 = (-half[i] - e) / f, t2 = (half[i] - e) / f;
      var sign = -1.0;
      if (t1 > t2) {
        final s = t1;
        t1 = t2;
        t2 = s;
        sign = 1.0;
      }
      if (t1 > tMin) {
        tMin = t1;
        normalAxis = i;
        normalSign = sign;
      }
      if (t2 < tMax) tMax = t2;
      if (tMin > tMax) return null;
    }
    if (tMax < 0) return null;
    final t = tMin > 0 ? tMin : tMax;
    final p = rel + d * t;
    final along = (axes[0].dot(p) + half[0]) / (2 * half[0]);
    return _Hit(t, axes[normalAxis] * normalSign, kind, along: along);
  }
}

/// A round pole between two points (a stand leg).
class _Rod {
  const _Rod(this.a, this.b, this.radius);

  final Vec3 a;
  final Vec3 b;
  final double radius;

  _Hit? intersect(Vec3 o, Vec3 d) {
    final axis = (b - a).normalised;
    final len = (b - a).length;
    final oa = o - a;
    final dPerp = d - axis * d.dot(axis);
    final oPerp = oa - axis * oa.dot(axis);
    final qa = dPerp.dot(dPerp), qb = 2 * dPerp.dot(oPerp), qc = oPerp.dot(oPerp) - radius * radius;
    final disc = qb * qb - 4 * qa * qc;
    if (qa < 1e-12 || disc < 0) return null;
    final t = (-qb - math.sqrt(disc)) / (2 * qa);
    if (t <= 0) return null;
    final p = oa + d * t;
    final s = p.dot(axis);
    if (s < 0 || s > len) return null;
    return _Hit(t, (p - axis * s).normalised, _Kind.leg);
  }
}
