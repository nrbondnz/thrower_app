import 'package:image/image.dart' as img;

import '../camera/camera_frame.dart';
import 'coarse_to_fine_locator.dart';
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

/// Debug aid: the frame's layout as one line, for logs.
String describeFrame(CameraFrame frame) => '${frame.width}×${frame.height} ${frame.format.name}, planes: '
    '${[for (final p in frame.planes) '${p.bytes.length} B, row ${p.bytesPerRow}, px ${p.bytesPerPixel}'].join(' | ')}';

/// Debug aid: converts the frame exactly as [locateInFrame] does and returns
/// it as a PNG, to see what the ring finder was given. Top-level for `compute`.
List<int>? debugFramePng((CameraFrame, int) input) {
  final (frame, rotation) = input;
  final rgb = frameToRgb(frame, rotation: rotation, maxSide: 1920);
  if (rgb == null) return null;
  final out = img.Image(width: rgb.width, height: rgb.height);
  for (var y = 0; y < rgb.height; y++) {
    for (var x = 0; x < rgb.width; x++) {
      out.setPixelRgb(x, y, rgb.red(x, y), rgb.green(x, y), rgb.blue(x, y));
    }
  }
  return img.encodePng(out);
}

/// Finds the target in a camera frame. Top-level and taking plain data so it
/// can run in a background isolate via `compute`:
/// (frame, clockwise rotation to upright, ring boundary radii).
FrameLocateResult locateInFrame((CameraFrame, int, List<double>) input) {
  final (frame, rotation, boundaries) = input;
  // Keep full camera resolution (1280 × 720 at ResolutionPreset.high): the
  // locator downscales for its rough pass and needs the detail for the
  // close-up pass. The cap only guards against unusually large frames.
  final rgb = frameToRgb(frame, rotation: rotation, maxSide: 1920);
  if (rgb == null) {
    return FrameLocateResult(TargetNotFound('Unsupported camera format ${frame.format.name}'), 0, 0);
  }
  return FrameLocateResult(buildTargetLocator(boundaries).locate(rgb), rgb.width, rgb.height);
}
