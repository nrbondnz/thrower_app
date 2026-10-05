import '../camera/camera_frame.dart';
import 'rgb_image.dart';

/// Converts a camera frame to an upright [RgbImage] no larger than [maxSide]
/// on its long side, sampling (not averaging) to keep it fast. Supports BGRA
/// (iOS) and YUV420 (Android); returns null for other formats.
RgbImage? frameToRgb(CameraFrame frame, {int maxSide = 600, int rotation = 0}) {
  final sample = _sampler(frame);
  if (sample == null) return null;

  final longest = frame.width > frame.height ? frame.width : frame.height;
  // Source pixels per output pixel (≥ 1; never upscales).
  final step = longest <= maxSide ? 1.0 : longest / maxSide;
  final w = (frame.width / step).floor(), h = (frame.height / step).floor();
  final swap = rotation == 90 || rotation == 270;
  final out = RgbImage.blank(swap ? h : w, swap ? w : h);

  for (var oy = 0; oy < out.height; oy++) {
    for (var ox = 0; ox < out.width; ox++) {
      // Position in the unrotated, downscaled frame.
      final (ux, uy) = switch (rotation) {
        90 => (oy, h - 1 - ox),
        180 => (w - 1 - ox, h - 1 - oy),
        270 => (w - 1 - oy, ox),
        _ => (ox, oy),
      };
      sample((ux * step).floor(), (uy * step).floor(), (r, g, b) => out.setPixel(ox, oy, r, g, b));
    }
  }
  return out;
}

typedef _Sink = void Function(int r, int g, int b);
typedef _Sampler = void Function(int x, int y, _Sink sink);

_Sampler? _sampler(CameraFrame frame) {
  switch (frame.format) {
    case FrameFormat.bgra8888:
      final p = frame.planes.first;
      return (x, y, sink) {
        final i = y * p.bytesPerRow + x * 4;
        sink(p.bytes[i + 2], p.bytes[i + 1], p.bytes[i]);
      };
    case FrameFormat.yuv420:
      if (frame.planes.length < 3) return null;
      final yp = frame.planes[0], up = frame.planes[1], vp = frame.planes[2];
      final uvStride = up.bytesPerPixel ?? 1;
      return (x, y, sink) {
        final luma = yp.bytes[y * yp.bytesPerRow + x];
        final uvIndex = (y >> 1) * up.bytesPerRow + (x >> 1) * uvStride;
        final u = up.bytes[uvIndex] - 128;
        final v = vp.bytes[(y >> 1) * vp.bytesPerRow + (x >> 1) * (vp.bytesPerPixel ?? 1)] - 128;
        sink(
          (luma + 1.402 * v).round().clamp(0, 255),
          (luma - 0.344136 * u - 0.714136 * v).round().clamp(0, 255),
          (luma + 1.772 * u).round().clamp(0, 255),
        );
      };
    case FrameFormat.nv21:
    case FrameFormat.unknown:
      return null;
  }
}
