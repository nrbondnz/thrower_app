import 'dart:math' as math;

import 'ellipse.dart';
import 'rgb_image.dart';

/// Draws a fake target photo with a known answer, for tests and the debug
/// screen: a log-like board with an irregular edge, rings in two alternating
/// colours (red/wood by default), a plain background, optional knife handles. Viewed from the side, the board is squashed
/// horizontally by cos([viewAngleDegrees]) (an affine view, no perspective).
class SyntheticTarget {
  SyntheticTarget({
    this.width = 800,
    this.height = 600,
    this.radiusPx = 220,
    this.viewAngleDegrees = 0,
    this.rotationDegrees = 0,
    this.ringRadii = const [0.2, 0.4, 0.6, 0.8, 1.0],
    this.knives = const [],
    this.colourA = (198, 40, 40),
    this.colourB = (227, 201, 160),
    this.background = (70, 130, 60),
    this.seed = 7,
  });

  final int width;
  final int height;

  /// Pixel radius of normalised radius 1, before squashing.
  final double radiusPx;
  final double viewAngleDegrees;

  /// Rotation of the squash direction, so the long axis isn't always vertical.
  final double rotationDegrees;
  final List<double> ringRadii;

  /// Knife handles as (x, y) in normalised target coordinates of where the
  /// handle's end sits; each is drawn as a dark bar.
  final List<(double, double)> knives;

  /// The bull's colour, repeated on every other ring (red paint by default).
  final (int, int, int) colourA;

  /// The colour of the rings between (bare wood by default).
  final (int, int, int) colourB;

  /// Behind the board (grass by default).
  final (int, int, int) background;
  final int seed;

  double get _squash => math.cos(viewAngleDegrees * math.pi / 180);
  double get _rot => rotationDegrees * math.pi / 180;
  double get _cx => width / 2;
  double get _cy => height / 2;

  /// Where the ring boundary at normalised radius [r] should appear.
  Ellipse expectedEllipse(double r) {
    final a = radiusPx * r, b = radiusPx * r * _squash;
    // Squash is along the rotated x axis, so the long axis is perpendicular.
    return Ellipse(cx: _cx, cy: _cy, semiMajor: a, semiMinor: b, angle: (_rot + math.pi / 2) % math.pi);
  }

  /// Image pixel → normalised target coordinates (inverse of the view).
  (double, double) _toTarget(double px, double py) {
    final dx = px - _cx, dy = py - _cy;
    final c = math.cos(_rot), s = math.sin(_rot);
    final u = (dx * c + dy * s) / _squash;
    final v = -dx * s + dy * c;
    return (u / radiusPx, v / radiusPx);
  }

  RgbImage render() {
    final random = math.Random(seed);
    final img = RgbImage.blank(width, height);
    // Irregular log edge: radius 1.08–1.16 varying with angle.
    final phase = random.nextDouble() * 6;
    double boardEdge(double angle) => 1.12 + 0.03 * math.sin(5 * angle + phase) + 0.01 * math.sin(13 * angle);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final (u, v) = _toTarget(x.toDouble(), y.toDouble());
        final r = math.sqrt(u * u + v * v);
        final noise = random.nextInt(20) - 10;
        final (int, int, int) colour;
        if (r > boardEdge(math.atan2(v, u))) {
          colour = background;
        } else {
          final ring = ringRadii.indexWhere((edge) => r <= edge);
          // The bull (ring 0) and every other ring are colour A; the outer ring
          // runs on to the board's edge, as on a painted log.
          final isA = ring == -1 ? (ringRadii.length - 1).isEven : ring.isEven;
          colour = isA ? colourA : colourB;
        }
        final (cr, cg, cb) = colour;
        img.setPixel(x, y, (cr + noise).clamp(0, 255), (cg + noise).clamp(0, 255), (cb + noise).clamp(0, 255));
      }
    }

    for (final (ku, kv) in knives) {
      _drawKnife(img, ku, kv);
    }
    return img;
  }

  /// A dark handle sticking out from (u, v) towards the top-right of the image.
  void _drawKnife(RgbImage img, double u, double v) {
    final c = math.cos(_rot), s = math.sin(_rot);
    final px = _cx + (u * radiusPx * _squash) * c - (v * radiusPx) * s;
    final py = _cy + (u * radiusPx * _squash) * s + (v * radiusPx) * c;
    final length = radiusPx * 0.35, halfWidth = radiusPx * 0.04;
    const dirX = 0.5, dirY = -0.866;
    for (var t = 0.0; t < length; t += 0.5) {
      for (var w = -halfWidth; w <= halfWidth; w += 0.5) {
        final x = (px + dirX * t - dirY * w).round();
        final y = (py + dirY * t + dirX * w).round();
        if (img.contains(x, y)) img.setPixel(x, y, 35, 30, 30);
      }
    }
  }
}
