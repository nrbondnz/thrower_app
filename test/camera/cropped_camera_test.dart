import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/camera_frame.dart';
import 'package:thrower_app/camera/cropped_camera.dart';
import 'package:thrower_app/camera/target_camera.dart';
import 'package:thrower_app/vision/frame_to_rgb.dart';
import 'package:thrower_app/vision/luma_image.dart';
import 'package:thrower_app/vision/rgb_image.dart';

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

  /// Set by tests that need the camera's clock.
  @override
  Duration now = Duration.zero;

  @override
  double get zoom => 1;

  @override
  Future<void> setZoom(double level) async {}

  @override
  Future<void> dispose() => controller.close();
}

/// An upright 12 × 8 picture where each pixel's red is its x × 10, green its
/// y × 10 and blue 7 (so any pixel tells where it came from).
RgbImage uprightPicture() {
  final img = RgbImage.blank(12, 8);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 12; x++) {
      img.setPixel(x, y, x * 10, y * 10, 7);
    }
  }
  return img;
}

/// The sensor-layout position of upright pixel ([ux], [uy]) in a picture
/// [w] × [h], for a camera whose frames need turning [rotation]° clockwise.
(int, int) sensorOf(int ux, int uy, int w, int h, int rotation) => switch (rotation) {
      90 => (uy, w - 1 - ux),
      180 => (w - 1 - ux, h - 1 - uy),
      270 => (h - 1 - uy, ux),
      _ => (ux, uy),
    };

/// [upright] as a BGRA camera frame in sensor layout for [rotation].
CameraFrame bgraFrame(RgbImage upright, int rotation) {
  final swap = rotation == 90 || rotation == 270;
  final sw = swap ? upright.height : upright.width, sh = swap ? upright.width : upright.height;
  final bytes = Uint8List(sw * sh * 4);
  for (var uy = 0; uy < upright.height; uy++) {
    for (var ux = 0; ux < upright.width; ux++) {
      final (sx, sy) = sensorOf(ux, uy, upright.width, upright.height, rotation);
      final i = (sy * sw + sx) * 4;
      bytes[i] = upright.blue(ux, uy);
      bytes[i + 1] = upright.green(ux, uy);
      bytes[i + 2] = upright.red(ux, uy);
      bytes[i + 3] = 255;
    }
  }
  return CameraFrame(
    width: sw,
    height: sh,
    format: FrameFormat.bgra8888,
    planes: [FramePlane(bytes: bytes, bytesPerRow: sw * 4, bytesPerPixel: 4)],
    timestamp: const Duration(milliseconds: 5),
  );
}

/// A greyscale YUV420 frame (Y = the upright red channel, U = V = 128), in
/// sensor layout for [rotation], with interleaved UV planes (2 bytes a pixel,
/// as Android sends) and rows padded to a wider stride.
CameraFrame yuvFrame(RgbImage upright, int rotation) {
  final swap = rotation == 90 || rotation == 270;
  final sw = swap ? upright.height : upright.width, sh = swap ? upright.width : upright.height;
  final stride = sw + 4;
  final y = Uint8List(stride * sh);
  for (var uy = 0; uy < upright.height; uy++) {
    for (var ux = 0; ux < upright.width; ux++) {
      final (sx, sy) = sensorOf(ux, uy, upright.width, upright.height, rotation);
      y[sy * stride + sx] = upright.red(ux, uy);
    }
  }
  final uv = Uint8List(stride * (sh >> 1))..fillRange(0, stride * (sh >> 1), 128);
  return CameraFrame(
    width: sw,
    height: sh,
    format: FrameFormat.yuv420,
    planes: [
      FramePlane(bytes: y, bytesPerRow: stride, bytesPerPixel: 1),
      FramePlane(bytes: uv, bytesPerRow: stride, bytesPerPixel: 2),
      FramePlane(bytes: Uint8List.sublistView(uv, 1), bytesPerRow: stride, bytesPerPixel: 2),
    ],
    timestamp: const Duration(milliseconds: 5),
  );
}

void main() {
  final upright = uprightPicture();
  // An upright rectangle: x 4–9, y 2–5 (6 × 4).
  const rect = (x: 4, y: 2, w: 6, h: 4);

  for (final rotation in [0, 90, 180, 270]) {
    group('a frame that needs turning $rotation°', () {
      CroppedCamera camera() => CroppedCamera(PushCamera(uprightRotation: rotation), x: rect.x, y: rect.y, width: rect.w, height: rect.h);

      test('BGRA: turned upright, the crop is exactly the upright rectangle', () {
        final c = camera();
        final rgb = frameToRgb(c.crop(bgraFrame(upright, rotation))!, rotation: c.uprightRotation)!;
        expect((rgb.width, rgb.height), (rect.w, rect.h));
        for (var y = 0; y < rect.h; y++) {
          for (var x = 0; x < rect.w; x++) {
            expect((rgb.red(x, y), rgb.green(x, y)), ((rect.x + x) * 10, (rect.y + y) * 10), reason: 'pixel ($x, $y)');
          }
        }
      });

      test('YUV: brightness frames of the crop, turned upright, are the upright rectangle', () {
        final c = camera();
        final luma = frameToLuma(c.crop(yuvFrame(upright, rotation))!, rotation: c.uprightRotation)!;
        expect((luma.width, luma.height), (rect.w, rect.h));
        for (var y = 0; y < rect.h; y++) {
          for (var x = 0; x < rect.w; x++) {
            expect(luma.at(x, y), (rect.x + x) * 10, reason: 'pixel ($x, $y)');
          }
        }
      });

      test('a compact copy keeps every pixel (BGRA and YUV)', () {
        final c = camera();
        for (final frame in [bgraFrame(upright, rotation), yuvFrame(upright, rotation)]) {
          final cropped = c.crop(frame)!;
          final copy = compactFrame(cropped);
          expect(frameToRgb(copy, rotation: rotation)!.pixels, frameToRgb(cropped, rotation: rotation)!.pixels);
          expect(copy.planes.first.bytes.length, lessThan(frame.planes.first.bytes.length));
        }
      });
    });
  }

  test('the crop reports the source\'s rotation and keeps the timestamp', () {
    final c = CroppedCamera(PushCamera(uprightRotation: 90), x: 4, y: 2, width: 6, height: 4);
    expect(c.uprightRotation, 90);
    expect(c.crop(bgraFrame(upright, 90))!.timestamp, const Duration(milliseconds: 5));
  });

  test("the rotation is fixed when the crop is made (the boards stay put in the sensor's picture)", () {
    final source = _TurningCamera();
    final c = CroppedCamera(source, x: 4, y: 2, width: 6, height: 4);
    source.rotation = 0;
    expect(c.uprightRotation, 90);
  });

  test('a frame the rectangle does not fit in is skipped, not a crash', () {
    final c = CroppedCamera(PushCamera(), x: 10, y: 6, width: 6, height: 4);
    expect(c.crop(bgraFrame(upright, 0)), isNull);
  });

  test("the clock is the source's", () {
    final source = PushCamera()..now = const Duration(seconds: 2);
    expect(CroppedCamera(source, x: 0, y: 0, width: 2, height: 2).now, const Duration(seconds: 2));
  });

  test('corners and sizes are rounded down to even numbers, so YUV colour planes line up', () {
    final camera = CroppedCamera(PushCamera(), x: 5, y: 3, width: 7, height: 5);
    expect((camera.x, camera.y, camera.width, camera.height), (4, 2, 6, 4));
  });

  test('frames come through as the source delivers them', () async {
    final source = PushCamera();
    final got = <CameraFrame>[];
    final sub = CroppedCamera(source, x: 0, y: 0, width: 2, height: 2).frames().listen(got.add);
    source.controller.add(bgraFrame(upright, 0));
    await pumpEventQueue();
    expect(got.single.width, 2);
    await sub.cancel();
  });
}

/// A camera whose reported rotation the test changes.
class _TurningCamera extends PushCamera {
  _TurningCamera() : super(uprightRotation: 90);

  int rotation = 90;

  @override
  int get uprightRotation => rotation;
}
