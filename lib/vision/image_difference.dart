import 'luma_image.dart';
import 'rgb_image.dart';

/// A rectangle of pixels: [x0, x1) × [y0, y1).
class PixelRect {
  const PixelRect(this.x0, this.y0, this.x1, this.y1);

  final int x0;
  final int y0;
  final int x1;
  final int y1;
}

/// The camera can move a little between frames: a phone propped on a sofa
/// arm or a tripod nudged by wind or an impact. On a target full of sharp ring
/// edges, a 1-pixel shift makes ~10% of the region "differ" (Nigel's A4 test,
/// 2026-10-09: 9.1% → "someone at the board"). So comparisons against an
/// older frame first find the small shift that best lines the frames up, and
/// every comparison asks whether a pixel's content is really new
/// ([lumaChanged]): a nudge moves existing edges; a knife is new content.
///
/// The (dx, dy) to add to [a]'s coordinates to find the matching pixel in [b],
/// searching up to ±[maxShift], judged on every [step]th pixel of [area].
(int, int) bestShift(LumaImage a, LumaImage b, PixelRect area, {int maxShift = 3, int step = 1}) {
  var best = -1, bx = 0, by = 0;
  for (var dy = -maxShift; dy <= maxShift; dy++) {
    for (var dx = -maxShift; dx <= maxShift; dx++) {
      var sum = 0;
      for (var y = area.y0; y < area.y1; y += step) {
        final sy = y + dy;
        if (sy < 0 || sy >= b.height) continue;
        for (var x = area.x0; x < area.x1; x += step) {
          final sx = x + dx;
          if (sx < 0 || sx >= b.width) continue;
          sum += (a.pixels[y * a.width + x] - b.pixels[sy * b.width + sx]).abs();
        }
      }
      // Prefer no shift on ties.
      if (best < 0 || sum < best || (sum == best && dx.abs() + dy.abs() < bx.abs() + by.abs())) {
        best = sum;
        bx = dx;
        by = dy;
      }
    }
  }
  return (bx, by);
}

/// Whether a(x, y) has really changed compared with [b] (shifted by
/// [dx], [dy]): its plain difference is over [limit] **and** even the
/// best-matching pixel within [tolerance] still differs by over half of it.
///
/// Tolerance alone also hides a thin knife (1–2 px wide at 320 px): on the
/// rendered ring-3 impact it cut the changed pixels from 78 to 24, under the
/// 28 needed to start an episode; combined, 42. On Nigel's nudged-camera frame
/// the combined test gives 2.6% (plain 9.1%), well clear of "blocked".
bool lumaChanged(LumaImage a, LumaImage b, int x, int y, int limit, {int dx = 0, int dy = 0, int tolerance = 1}) {
  final sx = x + dx, sy = y + dy;
  if (sx < 0 || sy < 0 || sx >= b.width || sy >= b.height) return false;
  if ((a.pixels[y * a.width + x] - b.pixels[sy * b.width + sx]).abs() <= limit) return false;
  return tolerantLumaDifference(a, b, x, y, dx: dx, dy: dy, tolerance: tolerance) > limit ~/ 2;
}

/// [lumaChanged] for colour (largest channel difference).
bool colourChanged(RgbImage a, RgbImage b, int x, int y, int limit, {int dx = 0, int dy = 0, int tolerance = 1}) {
  final sx = x + dx, sy = y + dy;
  if (sx < 0 || sy < 0 || sx >= b.width || sy >= b.height) return false;
  final i = (y * a.width + x) * 3, j = (sy * b.width + sx) * 3;
  var d = (a.pixels[i] - b.pixels[j]).abs();
  final dg = (a.pixels[i + 1] - b.pixels[j + 1]).abs(), db = (a.pixels[i + 2] - b.pixels[j + 2]).abs();
  if (dg > d) d = dg;
  if (db > d) d = db;
  if (d <= limit) return false;
  return tolerantColourDifference(a, b, x, y, dx: dx, dy: dy, tolerance: tolerance) > limit ~/ 2;
}

/// |a(x, y) − b| for the best-matching pixel of [b] within [tolerance] of
/// (x + dx, y + dy).
int tolerantLumaDifference(LumaImage a, LumaImage b, int x, int y, {int dx = 0, int dy = 0, int tolerance = 1}) {
  final v = a.pixels[y * a.width + x];
  var best = 255;
  for (var ty = -tolerance; ty <= tolerance; ty++) {
    final sy = y + dy + ty;
    if (sy < 0 || sy >= b.height) continue;
    for (var tx = -tolerance; tx <= tolerance; tx++) {
      final sx = x + dx + tx;
      if (sx < 0 || sx >= b.width) continue;
      final d = (v - b.pixels[sy * b.width + sx]).abs();
      if (d < best) best = d;
    }
  }
  return best;
}

/// The largest channel difference between a(x, y) and the best-matching pixel
/// of [b] within [tolerance] of (x + dx, y + dy).
int tolerantColourDifference(RgbImage a, RgbImage b, int x, int y, {int dx = 0, int dy = 0, int tolerance = 1}) {
  final i = (y * a.width + x) * 3;
  final r = a.pixels[i], g = a.pixels[i + 1], bl = a.pixels[i + 2];
  var best = 255;
  for (var ty = -tolerance; ty <= tolerance; ty++) {
    final sy = y + dy + ty;
    if (sy < 0 || sy >= b.height) continue;
    for (var tx = -tolerance; tx <= tolerance; tx++) {
      final sx = x + dx + tx;
      if (sx < 0 || sx >= b.width) continue;
      final j = (sy * b.width + sx) * 3;
      var d = (r - b.pixels[j]).abs();
      final dg = (g - b.pixels[j + 1]).abs(), db = (bl - b.pixels[j + 2]).abs();
      if (dg > d) d = dg;
      if (db > d) d = db;
      if (d < best) best = d;
    }
  }
  return best;
}
