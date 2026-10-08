import 'dart:math' as math;

import 'rgb_image.dart';

/// The face of a real board, taken from a near straight-on photo, for
/// [SyntheticScene] to paint onto its 3D board. Coordinates are normalised
/// target units (centre 0,0; outer edge of the outermost scoring ring at 1;
/// v up).
///
/// Built from the photo and the target's centre and scale in it (from the
/// ring finder's fit). On construction it traces the board's outline (where
/// bark meets background) and removes knives already stuck in the photo,
/// refilling them from the same ring a little further round, which works
/// because the rings are circular.
class PhotoBoardTexture {
  PhotoBoardTexture(
    this.photo, {
    required this.centreX,
    required this.centreY,
    required this.pixelsPerUnitX,
    required this.pixelsPerUnitY,
  }) {
    _traceEdge();
    _removeKnives();
  }

  final RgbImage photo;
  final double centreX;
  final double centreY;
  final double pixelsPerUnitX;
  final double pixelsPerUnitY;

  static const _angles = 720;
  late final List<double> _edge;
  late final RgbImage _clean;

  /// Board edge (normalised radius) in direction [angle] (radians, v up).
  double edgeAt(double angle) {
    var a = angle % (2 * math.pi);
    if (a < 0) a += 2 * math.pi;
    final f = a / (2 * math.pi) * _angles;
    final i = f.floor() % _angles, j = (i + 1) % _angles;
    return _edge[i] + (_edge[j] - _edge[i]) * (f - f.floor());
  }

  /// The largest board radius in any direction.
  double get maxEdge => _edge.reduce(math.max);

  /// The board's average radius (normalised units).
  double get meanEdge => _edge.reduce((a, b) => a + b) / _edge.length;

  /// Board colour at normalised (u, v), bilinearly sampled.
  (double, double, double) colourAt(double u, double v) {
    final x = centreX + u * pixelsPerUnitX, y = centreY - v * pixelsPerUnitY;
    final x0 = x.floor().clamp(0, _clean.width - 2), y0 = y.floor().clamp(0, _clean.height - 2);
    final fx = (x - x0).clamp(0.0, 1.0), fy = (y - y0).clamp(0.0, 1.0);
    double ch(int Function(int, int) c) {
      final top = c(x0, y0) + (c(x0 + 1, y0) - c(x0, y0)) * fx;
      final bottom = c(x0, y0 + 1) + (c(x0 + 1, y0 + 1) - c(x0, y0 + 1)) * fx;
      return top + (bottom - top) * fy;
    }

    return (ch(_clean.red), ch(_clean.green), ch(_clean.blue));
  }

  (int, int) _pixel(double u, double v) =>
      ((centreX + u * pixelsPerUnitX).round(), (centreY - v * pixelsPerUnitY).round());

  /// Grass, road and sky: green or grey (g ≥ r), or blue. Bark is brown (r > g).
  static bool _isBackground(int r, int g, int b) => g >= r - 8 || b > r;

  void _traceEdge() {
    final raw = List<double>.filled(_angles, 1.0);
    for (var i = 0; i < _angles; i++) {
      final a = 2 * math.pi * i / _angles;
      var rn = 1.0;
      // Step outwards until two background samples in a row.
      var streak = 0;
      for (var r = 0.9; r < 2.0; r += 0.004) {
        final (x, y) = _pixel(r * math.cos(a), r * math.sin(a));
        final bg = !photo.contains(x, y) || _isBackground(photo.red(x, y), photo.green(x, y), photo.blue(x, y));
        streak = bg ? streak + 1 : 0;
        if (streak == 2) {
          rn = r - 0.004;
          break;
        }
        rn = r;
      }
      raw[i] = rn;
    }
    // Median over ±6° removes spikes where the stand's legs meet the board.
    const half = 12;
    _edge = [
      for (var i = 0; i < _angles; i++)
        () {
          final window = [for (var k = -half; k <= half; k++) raw[(i + k) % _angles]]..sort();
          return window[half];
        }(),
    ];
  }

  /// Knife handles and blades: dark or grey (unsaturated) and not paint/wood.
  static bool _isForeign(int r, int g, int b) {
    final maxC = math.max(r, math.max(g, b)), minC = math.min(r, math.min(g, b));
    if (maxC == 0) return true;
    final saturation = (maxC - minC) / maxC;
    return saturation < 0.3 || maxC < 70;
  }

  void _removeKnives() {
    final w = photo.width, h = photo.height;
    final mask = List<bool>.filled(w * h, false);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final u = (x - centreX) / pixelsPerUnitX, v = (centreY - y) / pixelsPerUnitY;
        final rn = math.sqrt(u * u + v * v);
        if (rn > edgeAt(math.atan2(v, u)) - 0.04) continue;
        mask[y * w + x] = _isForeign(photo.red(x, y), photo.green(x, y), photo.blue(x, y));
      }
    }
    // Keep only large blobs (handles), not slits or specks, then grow them a
    // little to catch their rims and soft shadows.
    final minArea = (w * h * 0.00015).round();
    final knife = _largeRegions(mask, w, h, minArea);
    final grown = _dilate(knife, w, h, (w * 0.01).round());

    // Copy each hidden pixel from the same radius a fixed angle further round
    // (trying the offsets in the same order everywhere), so a whole patch of
    // real texture is copied rather than one pixel stretched into streaks.
    const offsets = [0.35, -0.35, 0.5, -0.5, 0.7, -0.7, 0.9, -0.9, 1.2, -1.2];
    _clean = RgbImage(w, h, photo.pixels.sublist(0));
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (!grown[y * w + x]) continue;
        final u = (x - centreX) / pixelsPerUnitX, v = (centreY - y) / pixelsPerUnitY;
        final rn = math.sqrt(u * u + v * v), a = math.atan2(v, u);
        for (final da in offsets) {
          final (sx, sy) = _pixel(rn * math.cos(a + da), rn * math.sin(a + da));
          if (photo.contains(sx, sy) && !grown[sy * w + sx]) {
            _clean.setPixel(x, y, photo.red(sx, sy), photo.green(sx, sy), photo.blue(sx, sy));
            break;
          }
        }
      }
    }
  }

  static List<bool> _largeRegions(List<bool> mask, int w, int h, int minArea) {
    final out = List<bool>.filled(mask.length, false);
    final seen = List<bool>.filled(mask.length, false);
    for (var start = 0; start < mask.length; start++) {
      if (!mask[start] || seen[start]) continue;
      final region = <int>[start];
      seen[start] = true;
      for (var k = 0; k < region.length; k++) {
        final i = region[k], x = i % w, y = i ~/ w;
        for (final n in [if (x > 0) i - 1, if (x < w - 1) i + 1, if (y > 0) i - w, if (y < h - 1) i + w]) {
          if (mask[n] && !seen[n]) {
            seen[n] = true;
            region.add(n);
          }
        }
      }
      if (region.length >= minArea) {
        for (final i in region) {
          out[i] = true;
        }
      }
    }
    return out;
  }

  static List<bool> _dilate(List<bool> mask, int w, int h, int radius) {
    // Two passes of a square max filter (separable).
    final rows = List<bool>.filled(mask.length, false);
    for (var y = 0; y < h; y++) {
      var last = -1 << 30;
      for (var x = 0; x < w; x++) {
        if (mask[y * w + x]) last = x;
        if (x - last <= radius) rows[y * w + x] = true;
      }
      last = 1 << 30;
      for (var x = w - 1; x >= 0; x--) {
        if (mask[y * w + x]) last = x;
        if (last - x <= radius) rows[y * w + x] = true;
      }
    }
    final out = List<bool>.filled(mask.length, false);
    for (var x = 0; x < w; x++) {
      var last = -1 << 30;
      for (var y = 0; y < h; y++) {
        if (rows[y * w + x]) last = y;
        if (y - last <= radius) out[y * w + x] = true;
      }
      last = 1 << 30;
      for (var y = h - 1; y >= 0; y--) {
        if (rows[y * w + x]) last = y;
        if (last - y <= radius) out[y * w + x] = true;
      }
    }
    return out;
  }

  /// The cleaned face (knives removed), for checking by eye.
  RgbImage get cleaned => _clean;
}
