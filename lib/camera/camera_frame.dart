import 'dart:typed_data';

/// Pixel layout of a [CameraFrame]. iOS delivers BGRA; Android delivers YUV.
enum FrameFormat { yuv420, nv21, bgra8888, unknown }

class FramePlane {
  const FramePlane({required this.bytes, required this.bytesPerRow, this.bytesPerPixel});

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
}

/// Clockwise rotation (0, 90, 180 or 270) that turns a back-camera frame
/// upright on screen. [sensorOrientation] is the camera's mounting angle
/// (usually 90 on phones); [deviceOrientation] is how far the phone is turned
/// from portrait-up (portrait-up 0, landscape-left 90, portrait-down 180,
/// landscape-right 270).
int frameRotation({required int sensorOrientation, required int deviceOrientation}) =>
    (sensorOrientation - deviceOrientation + 360) % 360;

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
