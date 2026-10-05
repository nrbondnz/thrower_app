import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/camera_frame.dart';
import 'package:thrower_app/vision/frame_to_rgb.dart';
import 'package:thrower_app/vision/rgb_image.dart';

/// Encodes [img] as a BGRA frame, with [padding] extra bytes per row.
CameraFrame bgraFrame(RgbImage img, {int padding = 0}) {
  final rowBytes = img.width * 4 + padding;
  final bytes = Uint8List(rowBytes * img.height);
  for (var y = 0; y < img.height; y++) {
    for (var x = 0; x < img.width; x++) {
      final i = y * rowBytes + x * 4;
      bytes[i] = img.blue(x, y);
      bytes[i + 1] = img.green(x, y);
      bytes[i + 2] = img.red(x, y);
      bytes[i + 3] = 255;
    }
  }
  return CameraFrame(
    width: img.width,
    height: img.height,
    format: FrameFormat.bgra8888,
    planes: [FramePlane(bytes: bytes, bytesPerRow: rowBytes, bytesPerPixel: 4)],
    timestamp: Duration.zero,
  );
}

/// Encodes [img] as YUV420 the way Android's CameraX delivers it: U and V at
/// half resolution with a pixel stride of 2 (interleaved buffers).
CameraFrame yuvFrame(RgbImage img) {
  final w = img.width, h = img.height;
  final yBytes = Uint8List(w * h);
  final uvRow = w; // pixel stride 2 × w/2 samples.
  final uBytes = Uint8List(uvRow * (h ~/ 2));
  final vBytes = Uint8List(uvRow * (h ~/ 2));
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final r = img.red(x, y), g = img.green(x, y), b = img.blue(x, y);
      yBytes[y * w + x] = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
      if (y.isEven && x.isEven) {
        final i = (y ~/ 2) * uvRow + (x ~/ 2) * 2;
        uBytes[i] = (128 - 0.168736 * r - 0.331264 * g + 0.5 * b).round().clamp(0, 255);
        vBytes[i] = (128 + 0.5 * r - 0.418688 * g - 0.081312 * b).round().clamp(0, 255);
      }
    }
  }
  return CameraFrame(
    width: w,
    height: h,
    format: FrameFormat.yuv420,
    planes: [
      FramePlane(bytes: yBytes, bytesPerRow: w, bytesPerPixel: 1),
      FramePlane(bytes: uBytes, bytesPerRow: uvRow, bytesPerPixel: 2),
      FramePlane(bytes: vBytes, bytesPerRow: uvRow, bytesPerPixel: 2),
    ],
    timestamp: Duration.zero,
  );
}

/// [img] rotated 90° anticlockwise: what a sideways sensor delivers for an
/// upright scene that needs a 90° clockwise turn to display.
RgbImage rotatedAnticlockwise(RgbImage img) {
  final out = RgbImage.blank(img.height, img.width);
  for (var y = 0; y < out.height; y++) {
    for (var x = 0; x < out.width; x++) {
      final sx = img.width - 1 - y, sy = x;
      out.setPixel(x, y, img.red(sx, sy), img.green(sx, sy), img.blue(sx, sy));
    }
  }
  return out;
}

/// A 3 × 2 image whose pixels are numbered 1–6 in the red channel.
RgbImage numbered() {
  final img = RgbImage.blank(3, 2);
  for (var i = 0; i < 6; i++) {
    img.setPixel(i % 3, i ~/ 3, i + 1, 0, 0);
  }
  return img;
}

List<List<int>> reds(RgbImage img) => [
      for (var y = 0; y < img.height; y++) [for (var x = 0; x < img.width; x++) img.red(x, y)],
    ];

void main() {
  group('frameRotation', () {
    const cases = <(int, int, int)>[(90, 0, 90), (90, 90, 0), (90, 180, 270), (90, 270, 180), (270, 0, 270), (0, 0, 0)];
    for (final (sensor, device, expected) in cases) {
      test('sensor $sensor°, device $device° → $expected°', () {
        expect(frameRotation(sensorOrientation: sensor, deviceOrientation: device), expected);
      });
    }
  });

  test('BGRA frame keeps its colours, ignoring row padding', () {
    final img = RgbImage.blank(2, 1)
      ..setPixel(0, 0, 200, 40, 30)
      ..setPixel(1, 0, 10, 220, 90);
    final out = frameToRgb(bgraFrame(img, padding: 8))!;
    expect([out.red(0, 0), out.green(0, 0), out.blue(0, 0)], [200, 40, 30]);
    expect([out.red(1, 0), out.green(1, 0), out.blue(1, 0)], [10, 220, 90]);
  });

  test('YUV420 frame with pixel stride 2 converts to RGB within rounding', () {
    final img = RgbImage.blank(4, 2);
    for (var x = 0; x < 4; x++) {
      img
        ..setPixel(x, 0, 198, 40, 40)
        ..setPixel(x, 1, 198, 40, 40);
    }
    final out = frameToRgb(yuvFrame(img))!;
    expect(out.red(2, 1), closeTo(198, 3));
    expect(out.green(2, 1), closeTo(40, 3));
    expect(out.blue(2, 1), closeTo(40, 3));
  });

  group('rotation', () {
    final cases = <(int, List<List<int>>)>[
      (0, [[1, 2, 3], [4, 5, 6]]),
      (90, [[4, 1], [5, 2], [6, 3]]),
      (180, [[6, 5, 4], [3, 2, 1]]),
      (270, [[3, 6], [2, 5], [1, 4]]),
    ];
    for (final (rotation, expected) in cases) {
      test('$rotation° clockwise', () {
        expect(reds(frameToRgb(bgraFrame(numbered()), rotation: rotation)!), expected);
      });
    }
  });

  test('downscales so the long side is at most maxSide', () {
    final out = frameToRgb(bgraFrame(RgbImage.blank(1920, 1080)), maxSide: 600)!;
    expect(out.width, lessThanOrEqualTo(600));
    expect(out.width, greaterThan(400));
    expect(out.height / out.width, closeTo(1080 / 1920, 0.01));
  });

  test('unsupported formats give null', () {
    const frame = CameraFrame(width: 1, height: 1, format: FrameFormat.nv21, planes: [], timestamp: Duration.zero);
    expect(frameToRgb(frame), isNull);
  });

  test('a sideways sensor frame rotated 90° matches the upright scene', () {
    final upright = numbered();
    expect(reds(frameToRgb(bgraFrame(rotatedAnticlockwise(upright)), rotation: 90)!), reds(upright));
  });
}
