import '../camera/camera_frame.dart';
import 'colour_ring_locator.dart';
import 'frame_to_rgb.dart';
import 'target_locator.dart';

/// The ring finder's result for one camera frame, in the coordinates of the
/// upright, downscaled image it ran on ([imageWidth] × [imageHeight]).
class FrameLocateResult {
  const FrameLocateResult(this.result, this.imageWidth, this.imageHeight);

  final TargetLocateResult result;
  final int imageWidth;
  final int imageHeight;
}

/// Finds the target in a camera frame. Top-level and taking plain data so it
/// can run in a background isolate via `compute`:
/// (frame, clockwise rotation to upright, ring boundary radii).
FrameLocateResult locateInFrame((CameraFrame, int, List<double>) input) {
  final (frame, rotation, boundaries) = input;
  final rgb = frameToRgb(frame, rotation: rotation);
  if (rgb == null) {
    return FrameLocateResult(TargetNotFound('Unsupported camera format ${frame.format.name}'), 0, 0);
  }
  return FrameLocateResult(ColourRingLocator(boundaryRadii: boundaries).locate(rgb), rgb.width, rgb.height);
}
