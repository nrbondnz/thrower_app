import 'dart:math' as math;

import 'ellipse.dart';
import 'image_difference.dart';
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

  /// A knife already in the board disappeared on its own (fell out). The
  /// change sits where that knife was.
  fellOut,
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

  /// The shape's smaller bounding-box side, in pixels. A knife has width; a
  /// 1-pixel sliver along a ring edge (left by a camera that moved slightly
  /// closer or further, which re-aligning can't undo) doesn't.
  int get thickness {
    var minX = imageWidth, maxX = -1, minY = imageHeight, maxY = -1;
    for (final i in pixels) {
      final x = i % imageWidth, y = i ~/ imageWidth;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    final w = maxX - minX + 1, h = maxY - minY + 1;
    return w < h ? w : h;
  }

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
  const ThrowOutcome(this.kind, {this.object, this.knownKnifeIndex});

  final ThrowOutcomeKind kind;

  /// For [ThrowOutcomeKind.stuck]: the new knife's shape. For
  /// [ThrowOutcomeKind.fellOut]: where the change was.
  final NewObject? object;

  /// For [ThrowOutcomeKind.fellOut]: which of the known knives fell out.
  final int? knownKnifeIndex;

  @override
  String toString() => 'ThrowOutcome(${kind.name}${object == null ? '' : ', ${object!.area} px'})';
}

/// Decides what a settled [MotionEpisode] was, by comparing the board before
/// and after it.
///
/// - The view was accepted as a new normal: **scene changed**.
/// - Someone stood at the board ([MotionEpisode.wasBlocked]) or the episode
///   changed a large share of the region at once ([visitPeak]): a **board
///   visit** (collecting knives), unless the visit left a knife-sized shape
///   that **appeared** ([appeared]), took none of the [knownKnives] and isn't
///   one of them: then someone placed a knife (or a pen, to test) by hand,
///   which is a **stuck** knife.
/// - Otherwise, pixels that differ from before by more than the episode's
///   threshold are grouped into connected shapes near the target. A shape
///   larger than [minKnifeShare] of the target's area that touches the target
///   is a **stuck** knife, if it is also at least 2 px thick (the rendered
///   knives show ~0.3–1.4% of the target's area, 4–16 px thick; the sliver a
///   slight camera move left along a ring edge on Nigel's A4 test was 1 px);
///   otherwise a **bounce-out**. Single noisy pixels and JPEG speckle never
///   form a shape that big.
///
/// [knownKnives] are the shapes of knives already in the board (recorded when
/// each stuck, cleared when someone collects them). A new shape that covers
/// most of one of them is that knife **disappearing** (fell out), not a new
/// knife: the before/after difference can't tell appearing from disappearing
/// on its own.
ThrowOutcome classifyThrow(
  MotionEpisode episode,
  TargetCalibration calibration, {
  List<NewObject> knownKnives = const [],
  double visitPeak = 0.10,
  double minKnifeShare = 0.0025,
  double searchMargin = 1.5,
  double fellOutOverlap = 0.5,
}) {
  if (episode.acceptedNewScene) return const ThrowOutcome(ThrowOutcomeKind.sceneChanged);
  final visit = episode.wasBlocked || episode.peakChange >= visitPeak;
  const visited = ThrowOutcome(ThrowOutcomeKind.boardVisit);
  final before = episode.before, after = episode.after;
  if (before == null || after == null) return visit ? visited : const ThrowOutcome(ThrowOutcomeKind.bounceOut);

  final object = findNewObject(before, after, calibration, threshold: episode.threshold, searchMargin: searchMargin);
  if (object == null ||
      object.thickness < 2 ||
      object.area < minKnifeArea(calibration, after.width, minKnifeShare: minKnifeShare)) {
    return visit ? visited : const ThrowOutcome(ThrowOutcomeKind.bounceOut);
  }

  final pixels = object.pixels.toSet();
  for (var k = 0; k < knownKnives.length; k++) {
    final known = knownKnives[k];
    if (known.imageWidth != object.imageWidth) continue;
    final shared = known.pixels.where(pixels.contains).length;
    if (shared >= fellOutOverlap * math.min(known.area, object.area)) {
      return visit ? visited : ThrowOutcome(ThrowOutcomeKind.fellOut, object: object, knownKnifeIndex: k);
    }
  }
  if (visit) {
    final tookKnife = knownKnives.any((k) => k.imageWidth == after.width && _gone(k, before, after, episode.threshold));
    if (tookKnife || !appeared(object, before, after)) return visited;
  }
  return ThrowOutcome(ThrowOutcomeKind.stuck, object: object);
}

/// Whether [object] (pixels that differ between [before] and [after]) is
/// something that **appeared** rather than something taken away: the picture
/// it stands out in is the one that has it. Each of its pixels is compared
/// with the board around the shape (unchanged pixels within 3 px), in both
/// pictures; a placed knife stands out in [after], a pulled-out one in
/// [before].
bool appeared(NewObject object, LumaImage before, LumaImage after) {
  final w = after.width, h = after.height;
  final inShape = object.pixels.toSet();
  var contrastBefore = 0.0, contrastAfter = 0.0;
  for (final i in object.pixels) {
    final x = i % w, y = i ~/ w;
    var sumB = 0, sumA = 0, n = 0;
    for (var dy = -3; dy <= 3; dy++) {
      for (var dx = -3; dx <= 3; dx++) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final j = ny * w + nx;
        if (inShape.contains(j)) continue;
        sumB += before.pixels[j];
        sumA += after.pixels[j];
        n++;
      }
    }
    if (n == 0) continue;
    contrastBefore += (before.pixels[i] - sumB / n).abs();
    contrastAfter += (after.pixels[i] - sumA / n).abs();
  }
  return contrastAfter > contrastBefore;
}

/// Whether most of a known knife's pixels changed: it was taken out.
bool _gone(NewObject knife, LumaImage before, LumaImage after, int threshold) {
  final w = after.width;
  final changed = knife.pixels.where((i) => lumaChanged(after, before, i % w, i ~/ w, threshold)).length;
  return changed >= knife.area / 2;
}

/// The smallest new shape (pixels, in a frame [frameWidth] wide) that counts
/// as a stuck knife: [minKnifeShare] of the target's area, at least 4 pixels.
double minKnifeArea(TargetCalibration calibration, int frameWidth, {double minKnifeShare = 0.0025}) {
  final outer = calibration.outer.rescaled(frameWidth / calibration.imageWidth);
  return math.max(4, minKnifeShare * math.pi * outer.semiMajor * outer.semiMinor);
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
  // Re-align a small camera shift and count only really new content (see
  // image_difference.dart), so a nudged camera doesn't look like new objects.
  final (dx, dy) = bestShift(after, before, PixelRect(x0, y0, x1, y1));
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = y * w + x;
      if (inSearch(x, y) && lumaChanged(after, before, x, y, threshold, dx: dx, dy: dy)) changed[i] = true;
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
