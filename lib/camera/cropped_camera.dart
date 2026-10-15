import 'dart:typed_data';

import 'camera_frame.dart';
import 'target_camera.dart';

/// One part of another camera's picture, as a camera of its own: Quick draw
/// watches each player's board with the single-board throw detection, which
/// then sees only that board, at the source's full detail. Frames are views
/// into the source frame's bytes (no copying).
///
/// The rectangle is in the source's upright picture, which must need no
/// rotation (the Live test recordings; a live camera's sideways frames would
/// need the rectangle rotated too). [x] and [y] are rounded down to even
/// numbers, so a YUV frame's half-size colour planes line up.
class CroppedCamera implements TargetCamera {
  CroppedCamera(this.source, {required int x, required int y, required this.width, required this.height})
      : x = x & ~1,
        y = y & ~1 {
    if (source.uprightRotation != 0) {
      throw UnsupportedError('CroppedCamera needs an upright source (rotation ${source.uprightRotation})');
    }
  }

  final TargetCamera source;
  final int x;
  final int y;
  final int width;
  final int height;

  @override
  Stream<CameraFrame> frames() => source.frames().map(crop);

  /// [frame]'s part inside the rectangle.
  CameraFrame crop(CameraFrame frame) {
    FramePlane view(FramePlane p, int px, int py) => FramePlane(
          bytes: Uint8List.sublistView(p.bytes, py * p.bytesPerRow + px * (p.bytesPerPixel ?? 1)),
          bytesPerRow: p.bytesPerRow,
          bytesPerPixel: p.bytesPerPixel,
        );
    final planes = switch (frame.format) {
      FrameFormat.bgra8888 => [view(frame.planes.first, x, y)],
      FrameFormat.yuv420 => [
          view(frame.planes[0], x, y),
          for (final p in frame.planes.skip(1)) view(p, x >> 1, y >> 1),
        ],
      FrameFormat.nv21 || FrameFormat.unknown => frame.planes,
    };
    return CameraFrame(width: width, height: height, format: frame.format, planes: planes, timestamp: frame.timestamp);
  }

  @override
  int get uprightRotation => 0;

  @override
  int get minChange => source.minChange;

  @override
  double get maxZoom => 1;

  @override
  double get zoom => 1;

  @override
  Future<void> setZoom(double level) async {}

  /// The source belongs to whoever made this; nothing to release here.
  @override
  Future<void> dispose() async {}
}
