import 'dart:math' as math;

import 'image_difference.dart';
import 'luma_image.dart';
import 'motion_detector.dart';

/// How far the picture moved between [before] and [after] (frames of the
/// same size, ~320 px as the watchers analyse them) over the board's
/// [region], in pixels: the shift that best lines them up ([bestShift], up
/// to ±[maxShift]). A knife or a hand changes a part of the picture; a
/// jogged phone moves all of it (score corrections story, 2026-10-17:
/// someone tapped the phone to change a score).
double cameraShift(LumaImage before, LumaImage after, WatchRegion region, {int maxShift = 8}) {
  final x0 = (region.left * after.width).floor(), x1 = (region.right * after.width).ceil();
  final y0 = (region.top * after.height).floor(), y1 = (region.bottom * after.height).ceil();
  if (x1 <= x0 || y1 <= y0) return 0;
  final (dx, dy) = bestShift(after, before, PixelRect(x0, y0, x1, y1), maxShift: maxShift, step: 2);
  return math.sqrt(dx * dx + dy * dy);
}

/// A shift this large (pixels at ~320 px) means the phone moved: the
/// rings no longer line up with the locked calibration. Measured
/// 2026-10-17: still frames of the Live test footage shift by up to 1 px
/// (compression), Nigel's sofa-arm nudge of 2026-10-09 by 1.4 px (treated
/// as harmless by the motion detector too); renders with a knife or a
/// person added, 0. On boards of 40–65 px radius at 320 px, 2 px is
/// 0.03–0.05 of the radius: a sixth to a quarter of a ring's width, enough
/// to put a knife near a line in the next ring.
const phoneMovedShift = 2.0;

/// Whether the phone moved between [before] and [after] ([cameraShift] at
/// least [phoneMovedShift]).
bool phoneMoved(LumaImage before, LumaImage after, WatchRegion region) =>
    cameraShift(before, after, region) >= phoneMovedShift;
