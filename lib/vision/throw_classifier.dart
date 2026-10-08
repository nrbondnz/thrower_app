import 'dart:math' as math;

import 'ellipse.dart';
import 'luma_image.dart';
import 'motion_detector.dart';
import 'target_calibration.dart';

enum ThrowOutcomeKind {
  /// A new knife is stuck in the board.
  stuck,

  /// Something moved but nothing new is on the board: the knife bounced off
  /// (scores 0).
  bounceOut,

  /// Someone was at the board (blocking it): knives being pulled out, the end
  /// of a round. Not a throw.
  boardVisit,

  /// The whole view changed and was accepted as the new normal (lights
  /// switched on, camera knocked). Not a throw; the calibration may be stale.
  sceneChanged,
}

/// A new object found on the board: the pixels (in the brightness frame) that
/// differ from before and form one connected shape.
class NewObject {
  const NewObject(this.pixels, this.imageWidth, this.imageHeight);

  /// Indices (y × width + x) into the brightness frame.
  final List<int> pixels;
  final int imageWidth;
  final int imageHeight;

  int get area => pixels.length;

  Point2 get centroid {
    var sx = 0.0, sy = 0.0;
    for (final i in pixels) {
      sx += i % imageWidth;
      sy += i ~/ imageWidth;
    }
    return Point2(sx / area, sy / area);
  }
}

class ThrowOutcome {
  const ThrowOutcome(this.kind, {this.object});

  final ThrowOutcomeKind kind;

  /// For [ThrowOutcomeKind.stuck]: the new knife's shape.
  final NewObject? object;

  @override
  String toString() => 'ThrowOutcome(${kind.name}${object == null ? '' : ', ${object!.area} px'})';
}

/// Decides what a settled [MotionEpisode] was, by comparing the board before
/// and after it.
///
/// - Someone stood at the board ([MotionEpisode.wasBlocked]) or the episode
///   changed a large share of the region at once ([visitPeak]): a **board
///   visit**.
/// - The view was accepted as a new normal: **scene changed**.
/// - Otherwise, pixels that differ from before by more than the episode's
///   threshold are grouped into connected shapes near the target. A shape
///   larger than [minKnifeShare] of the target's area that touches the target
///   is a **stuck** knife (a stuck knife shows ~0.5–1% of the target's area);
///   otherwise a **bounce-out**. Single noisy pixels and JPEG speckle never
///   form a shape that big.
ThrowOutcome classifyThrow(
  MotionEpisode episode,
  TargetCalibration calibration, {
  double visitPeak = 0.10,
  double minKnifeShare = 0.0025,
  double searchMargin = 1.5,
}) {
  if (episode.acceptedNewScene) return const ThrowOutcome(ThrowOutcomeKind.sceneChanged);
  if (episode.wasBlocked || episode.peakChange >= visitPeak) return const ThrowOutcome(ThrowOutcomeKind.boardVisit);
  final before = episode.before, after = episode.after;
  if (before == null || after == null) return const ThrowOutcome(ThrowOutcomeKind.bounceOut);

  final object = findNewObject(before, after, calibration, threshold: episode.threshold, searchMargin: searchMargin);
  final scale = after.width / calibration.imageWidth;
  final outer = calibration.outer.rescaled(scale);
  final targetArea = math.pi * outer.semiMajor * outer.semiMinor;
  if (object != null && object.area >= math.max(4, minKnifeShare * targetArea)) {
    return ThrowOutcome(ThrowOutcomeKind.stuck, object: object);
  }
  return const ThrowOutcome(ThrowOutcomeKind.bounceOut);
}

/// The largest connected shape (8-connected) of pixels that differ between
/// [before] and [after] by more than [threshold], within [searchMargin] × the
/// outer ring, that touches the target (the outer ring × 1.05). Null if none.
NewObject? findNewObject(
  LumaImage before,
  LumaImage after,
  TargetCalibration calibration, {
  required int threshold,
  double searchMargin = 1.5,
}) {
  final w = after.width, h = after.height;
  final outer = calibration.outer.rescaled(w / calibration.imageWidth);
  bool inSearch(int x, int y) => outer.normalisedRadius(Point2(x.toDouble(), y.toDouble())) <= searchMargin;
  bool onTarget(int i) => outer.normalisedRadius(Point2((i % w).toDouble(), (i ~/ w).toDouble())) <= 1.05;

  final changed = List<bool>.filled(w * h, false);
  final x0 = math.max(0, (outer.cx - outer.semiMajor * searchMargin).floor());
  final x1 = math.min(w, (outer.cx + outer.semiMajor * searchMargin).ceil());
  final y0 = math.max(0, (outer.cy - outer.semiMajor * searchMargin).floor());
  final y1 = math.min(h, (outer.cy + outer.semiMajor * searchMargin).ceil());
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = y * w + x;
      if ((after.pixels[i] - before.pixels[i]).abs() > threshold && inSearch(x, y)) changed[i] = true;
    }
  }

  NewObject? best;
  final seen = List<bool>.filled(w * h, false);
  for (var start = 0; start < changed.length; start++) {
    if (!changed[start] || seen[start]) continue;
    final shape = <int>[start];
    seen[start] = true;
    var touches = false;
    for (var k = 0; k < shape.length; k++) {
      final i = shape[k], x = i % w, y = i ~/ w;
      if (!touches && onTarget(i)) touches = true;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          final n = ny * w + nx;
          if (changed[n] && !seen[n]) {
            seen[n] = true;
            shape.add(n);
          }
        }
      }
    }
    if (touches && (best == null || shape.length > best.area)) best = NewObject(shape, w, h);
  }
  return best;
}
