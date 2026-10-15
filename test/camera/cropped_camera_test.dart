import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/camera_frame.dart';
import 'package:thrower_app/camera/cropped_camera.dart';
import 'package:thrower_app/camera/target_camera.dart';
import 'package:thrower_app/vision/frame_to_rgb.dart';
import 'package:thrower_app/vision/luma_image.dart';

/// A camera whose frames are pushed by the test.
class PushCamera implements TargetCamera {
  PushCamera({this.uprightRotation = 0});

  final controller = StreamController<CameraFrame>.broadcast();

  @override
  final int uprightRotation;

  @override
  Stream<CameraFrame> frames() => controller.stream;

  @override
  int get minChange => 20;

  @override
  double get maxZoom => 1;

  @override
  double get zoom => 1;

  @override
  Future<void> setZoom(double level) async {}

  @override
  Future<void> dispose() => controller.close();
}

/// A 10 × 8 BGRA frame where each pixel's red is its x and green its y.
CameraFrame gradient() {
  final bytes = Uint8List(10 * 8 * 4);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 10; x++) {
      final i = (y * 10 + x) * 4;
      bytes[i + 2] = x * 10;
      bytes[i + 1] = y * 10;
      bytes[i + 3] = 255;
    }
  }
  return CameraFrame(
    width: 10,
    height: 8,
    format: FrameFormat.bgra8888,
    planes: [FramePlane(bytes: bytes, bytesPerRow: 40, bytesPerPixel: 4)],
    timestamp: const Duration(milliseconds: 5),
  );
}

void main() {
  test('a BGRA frame is cut to the rectangle, keeping its timestamp', () {
    final crop = CroppedCamera(PushCamera(), x: 4, y: 2, width: 3, height: 5).crop(gradient());
    final rgb = frameToRgb(crop)!;
    expect((rgb.width, rgb.height, crop.timestamp), (3, 5, const Duration(milliseconds: 5)));
    expect((rgb.red(0, 0), rgb.green(0, 0)), (40, 20));
    expect((rgb.red(2, 4), rgb.green(2, 4)), (60, 60));
  });

  test('brightness frames come from the rectangle too', () {
    final luma = frameToLuma(CroppedCamera(PushCamera(), x: 4, y: 2, width: 3, height: 5).crop(gradient()))!;
    expect((luma.width, luma.height), (3, 5));
  });

  test('odd corners are rounded down to even, so YUV colour planes line up', () {
    final camera = CroppedCamera(PushCamera(), x: 5, y: 3, width: 2, height: 2);
    expect((camera.x, camera.y), (4, 2));
  });

  test('frames come through as the source delivers them', () async {
    final source = PushCamera();
    final got = <CameraFrame>[];
    final sub = CroppedCamera(source, x: 0, y: 0, width: 2, height: 2).frames().listen(got.add);
    source.controller.add(gradient());
    await pumpEventQueue();
    expect(got.single.width, 2);
    await sub.cancel();
  });

  test('a sideways source is refused (the rectangle would need turning too)', () {
    expect(() => CroppedCamera(PushCamera(uprightRotation: 90), x: 0, y: 0, width: 2, height: 2), throwsUnsupportedError);
  });
}
