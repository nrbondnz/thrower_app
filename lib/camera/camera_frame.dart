import 'dart:typed_data';

/// Pixel layout of a [CameraFrame]. iOS delivers BGRA; Android delivers YUV.
enum FrameFormat { yuv420, nv21, bgra8888, unknown }

class FramePlane {
  const FramePlane({required this.bytes, required this.bytesPerRow, this.bytesPerPixel});

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
}

/// One camera frame, independent of the camera plugin, so the vision layer can
/// be fed recorded frames in tests.
class CameraFrame {
  const CameraFrame({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
    required this.timestamp,
  });

  final int width;
  final int height;
  final FrameFormat format;
  final List<FramePlane> planes;

  /// Time the frame arrived, from a monotonic clock started with the camera.
  final Duration timestamp;
}
