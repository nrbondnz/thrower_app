import 'dart:typed_data';

import '../camera/camera_frame.dart';
import 'rgb_image.dart';

/// An 8-bit brightness (luma) image, row-major. Motion detection works on
/// these: small, fast, and on Android straight from the camera's Y plane.
class LumaImage {
  LumaImage(this.width, this.height, this.pixels) : assert(pixels.length == width * height);

  final int width;
  final int height;
  final Uint8List pixels;

  int at(int x, int y) => pixels[y * width + x];

  /// Brightness of an RGB image (ITU-R BT.601 weights).
  factory LumaImage.fromRgb(RgbImage rgb) {
    final out = Uint8List(rgb.width * rgb.height);
    final p = rgb.pixels;
    for (var i = 0, j = 0; j < out.length; i += 3, j++) {
      out[j] = (p[i] * 77 + p[i + 1] * 150 + p[i + 2] * 29) >> 8;
    }
    return LumaImage(rgb.width, rgb.height, out);
  }
}

/// A camera frame's brightness, upright (rotated clockwise by [rotation]) and
/// downscaled so its long side is about [maxSide] (sampled, not averaged).
/// YUV420 reads the Y plane directly; BGRA is converted. Null for other
/// formats.
LumaImage? frameToLuma(CameraFrame frame, {int rotation = 0, int maxSide = 320}) {
  final longest = frame.width > frame.height ? frame.width : frame.height;
  final step = longest <= maxSide ? 1.0 : longest / maxSide;
  final w = (frame.width / step).floor(), h = (frame.height / step).floor();
  final plane = frame.planes.isEmpty ? null : frame.planes.first;
  if (plane == null) return null;

  final int Function(int x, int y) sample;
  switch (frame.format) {
    case FrameFormat.yuv420:
    case FrameFormat.nv21:
      sample = (x, y) => plane.bytes[y * plane.bytesPerRow + x];
    case FrameFormat.bgra8888:
      sample = (x, y) {
        final i = y * plane.bytesPerRow + x * 4;
        return (plane.bytes[i + 2] * 77 + plane.bytes[i + 1] * 150 + plane.bytes[i] * 29) >> 8;
      };
    case FrameFormat.unknown:
      return null;
  }

  final swap = rotation == 90 || rotation == 270;
  final ow = swap ? h : w, oh = swap ? w : h;
  final out = Uint8List(ow * oh);
  for (var oy = 0; oy < oh; oy++) {
    for (var ox = 0; ox < ow; ox++) {
      final (ux, uy) = switch (rotation) {
        90 => (oy, h - 1 - ox),
        180 => (w - 1 - ox, h - 1 - oy),
        270 => (w - 1 - oy, ox),
        _ => (ox, oy),
      };
      out[oy * ow + ox] = sample((ux * step).floor(), (uy * step).floor());
    }
  }
  return LumaImage(ow, oh, out);
}
