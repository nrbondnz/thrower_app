import 'dart:typed_data';

import 'camera_frame.dart';
import 'target_camera.dart';

/// One part of another camera's picture, as a camera of its own: Quick draw
/// watches each player's board with the single-board throw detection, which
/// then sees only that board, at the source's full detail. Frames are views
/// into the source frame's bytes (no copying; see [compactFrame] to keep one).
///
/// The rectangle ([x], [y], [width], [height]) is in the source's **upright**
/// picture. A source whose frames arrive sideways (Android's camera: see
/// `TargetCamera.uprightRotation`) is cut along the same rectangle in the
/// sensor's own layout, and this camera reports the same rotation, so whoever
/// turns its frames upright gets exactly that rectangle, upright, without the
/// whole frame ever being turned. All four are rounded down to even numbers,
/// so a YUV frame's half-size colour planes line up however it's turned.
///
/// The rotation is the source's **when this is made** (when the boards are
/// locked), and stays: the camera is on a stand, so the boards don't move in
/// the sensor's picture even if the phone's reported orientation changes
/// (Review Agent, 2026-10-15). A frame whose rectangle wouldn't fit (a
/// different size) is skipped.
class CroppedCamera implements TargetCamera {
  CroppedCamera(this.source, {required int x, required int y, required int width, required int height})
      : x = x & ~1,
        y = y & ~1,
        width = width & ~1,
        height = height & ~1,
        uprightRotation = source.uprightRotation;

  final TargetCamera source;
  final int x;
  final int y;
  final int width;
  final int height;

  @override
  Stream<CameraFrame> frames() => source.frames().map(crop).where((f) => f != null).cast<CameraFrame>();

  /// [frame]'s part inside the rectangle, still in the sensor's layout; null
  /// if the rectangle doesn't fit in it.
  CameraFrame? crop(CameraFrame frame) {
    final (sx, sy, sw, sh) = sensorRect(frame.width, frame.height, uprightRotation);
    if (sx < 0 || sy < 0 || sx + sw > frame.width || sy + sh > frame.height) return null;
    FramePlane view(FramePlane p, int px, int py) => FramePlane(
          bytes: Uint8List.sublistView(p.bytes, py * p.bytesPerRow + px * (p.bytesPerPixel ?? 1)),
          bytesPerRow: p.bytesPerRow,
          bytesPerPixel: p.bytesPerPixel,
        );
    final planes = switch (frame.format) {
      FrameFormat.bgra8888 => [view(frame.planes.first, sx, sy)],
      FrameFormat.yuv420 => [
          view(frame.planes[0], sx, sy),
          for (final p in frame.planes.skip(1)) view(p, sx >> 1, sy >> 1),
        ],
      FrameFormat.nv21 || FrameFormat.unknown => frame.planes,
    };
    return CameraFrame(width: sw, height: sh, format: frame.format, planes: planes, timestamp: frame.timestamp);
  }

  /// The rectangle in a sensor frame [frameWidth] × [frameHeight] that turns
  /// (clockwise by [rotation]) into the upright rectangle: (x, y, w, h) in the
  /// sensor's layout. The inverse of `frameToRgb`'s mapping.
  (int, int, int, int) sensorRect(int frameWidth, int frameHeight, int rotation) => switch (rotation) {
        90 => (y, frameHeight - x - width, height, width),
        180 => (frameWidth - x - width, frameHeight - y - height, width, height),
        270 => (frameWidth - y - height, x, height, width),
        _ => (x, y, width, height),
      };

  /// The source's turn when this was made: the crop is in the sensor's layout.
  @override
  final int uprightRotation;

  @override
  int get minChange => source.minChange;

  @override
  double get maxZoom => 1;

  @override
  Duration get now => source.now;

  @override
  double get zoom => 1;

  @override
  Future<void> setZoom(double level) async {}

  /// The source belongs to whoever made this; nothing to release here.
  @override
  Future<void> dispose() async {}
}

/// A copy of [frame] holding only its own pixels, packed tightly: a cropped
/// frame is a view into the whole source frame, which this lets go of (a
/// 250 × 250 board crop keeps ~250 KB, not the 1–4 MB frame around it).
CameraFrame compactFrame(CameraFrame frame) {
  FramePlane pack(FramePlane p, int rows, int rowBytes) {
    final out = Uint8List(rows * rowBytes);
    for (var r = 0; r < rows; r++) {
      final from = r * p.bytesPerRow;
      // The last row of a view may stop short of a full stride.
      final n = rowBytes < p.bytes.length - from ? rowBytes : p.bytes.length - from;
      out.setRange(r * rowBytes, r * rowBytes + n, p.bytes, from);
    }
    return FramePlane(bytes: out, bytesPerRow: rowBytes, bytesPerPixel: p.bytesPerPixel);
  }

  final planes = switch (frame.format) {
    FrameFormat.bgra8888 => [pack(frame.planes.first, frame.height, frame.width * 4)],
    FrameFormat.yuv420 => [
        pack(frame.planes[0], frame.height, frame.width * (frame.planes[0].bytesPerPixel ?? 1)),
        for (final p in frame.planes.skip(1))
          // Colour at half size each way; interleaved UV is 2 bytes a pixel.
          pack(p, frame.height >> 1, ((frame.width >> 1) - 1) * (p.bytesPerPixel ?? 1) + 1),
      ],
    FrameFormat.nv21 || FrameFormat.unknown => frame.planes,
  };
  return CameraFrame(width: frame.width, height: frame.height, format: frame.format, planes: planes, timestamp: frame.timestamp);
}
