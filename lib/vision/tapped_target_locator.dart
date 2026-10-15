import 'dart:math' as math;

import '../camera/camera_frame.dart';
import 'coarse_to_fine_locator.dart';
import 'colour_ring_locator.dart';
import 'contrast_normalising_locator.dart';
import 'ellipse.dart';
import 'frame_to_rgb.dart';
import 'rgb_image.dart';
import 'target_locator.dart';

/// Finds the board the user tapped (Quick draw: there may be more boards in
/// the picture than players, so the user picks them). Only a square window
/// around [tap] is searched, [window] × the picture's shorter side, with
/// the tap tried first as the board's centre ([ColourRingLocator.seed]).
/// The window is enlarged [enlarge] times before the rings are traced, as
/// small boards are traced far more reliably enlarged (the Live test's 140 px
/// crops, 2026-10-11).
///
/// On the Quick draw clip's 16 still frames (boards ~125 px across, JPEG
/// q20), tapped on their centres, the red board / the green and red board
/// were found on: 15 / 10 of 16 at the finder's usual 1.3× enlargement here,
/// 15 / 15 at 2.6×, 16 / 15–16 at 3× (2026-10-14).
///
/// Searching the whole picture instead found the wrong board, or none: the
/// ring finder learns the two ring colours from what it's shown, and boards
/// side by side can be painted differently (the Quick draw clip, 2026-10-14).
TargetLocateResult locateTargetAt(
  RgbImage image,
  Point2 tap,
  List<double> boundaryRadii, {
  double window = 0.45,
  double enlarge = 3,
}) {
  final side = math.min((window * math.min(image.width, image.height)).round(), math.min(image.width, image.height));
  final working = math.max(420, (side * enlarge).round());
  final x0 = math.max(0, math.min((tap.x - side / 2).round(), image.width - side));
  final y0 = math.max(0, math.min((tap.y - side / 2).round(), image.height - side));
  final seed = Point2(tap.x - x0, tap.y - y0);
  final locator = ContrastNormalisingLocator(ColourRingLocator(
    boundaryRadii: boundaryRadii,
    seed: seed,
    workingSize: working,
    minWorkingSize: working,
  ));
  return CoarseToFineLocator.moved(locator.locate(image.crop(x0, y0, side, side)), x0.toDouble(), y0.toDouble());
}

/// The boards found at each tap, in tap order (Player 1 first), in the
/// upright image's coordinates ([imageWidth] × [imageHeight]).
class TappedTargetsResult {
  const TappedTargetsResult(this.boards, this.imageWidth, this.imageHeight);

  final List<TargetLocateResult> boards;
  final int imageWidth;
  final int imageHeight;
}

/// [locateTargetAt] for each tap, on one camera frame. Top-level and taking
/// plain data so it can run in a background isolate via `compute`: (frame,
/// clockwise rotation to upright, ring boundary radii, taps as **fractions**
/// of the upright picture's width and height). Fractions, because the screen
/// shows the upright picture at its own size, and only here, after turning
/// the frame upright, is the picture's size in pixels known (a live camera's
/// frames arrive sideways on Android).
TappedTargetsResult locateTappedInFrame((CameraFrame, int, List<double>, List<Point2>) input) {
  final (frame, rotation, boundaries, taps) = input;
  final rgb = frameToRgb(frame, rotation: rotation, maxSide: 1920);
  if (rgb == null) {
    return TappedTargetsResult(
        [for (final _ in taps) TargetNotFound('Unsupported camera format ${frame.format.name}')], 0, 0);
  }
  return TappedTargetsResult(
    [for (final t in taps) locateTargetAt(rgb, Point2(t.x * rgb.width, t.y * rgb.height), boundaries)],
    rgb.width,
    rgb.height,
  );
}
