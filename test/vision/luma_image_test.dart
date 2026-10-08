import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/luma_image.dart';
import 'package:thrower_app/vision/rgb_image.dart';

import 'frame_to_rgb_test.dart' show bgraFrame, numbered, rotatedAnticlockwise, yuvFrame;

void main() {
  test('luma of an RGB image uses BT.601 weights', () {
    final rgb = RgbImage.blank(3, 1)
      ..setPixel(0, 0, 255, 0, 0)
      ..setPixel(1, 0, 0, 255, 0)
      ..setPixel(2, 0, 255, 255, 255);
    final l = LumaImage.fromRgb(rgb);
    expect(l.at(0, 0), closeTo(76, 1));
    expect(l.at(1, 0), closeTo(149, 1));
    expect(l.at(2, 0), closeTo(255, 1));
  });

  test('YUV420 frames give the Y plane directly', () {
    final rgb = RgbImage.blank(4, 2);
    for (var x = 0; x < 4; x++) {
      rgb
        ..setPixel(x, 0, 100, 100, 100)
        ..setPixel(x, 1, 200, 200, 200);
    }
    final l = frameToLuma(yuvFrame(rgb))!;
    expect(l.at(0, 0), 100);
    expect(l.at(3, 1), 200);
  });

  test('BGRA frames are converted to brightness', () {
    final l = frameToLuma(bgraFrame(RgbImage.blank(2, 1)..setPixel(1, 0, 255, 255, 255)))!;
    expect(l.at(0, 0), 0);
    expect(l.at(1, 0), closeTo(255, 1));
  });

  test('a sideways sensor frame rotated 90° matches the upright scene', () {
    final upright = numbered(); // reds 1..6 in a 3 × 2 image.
    final l = frameToLuma(bgraFrame(rotatedAnticlockwise(upright)), rotation: 90)!;
    expect([l.width, l.height], [3, 2]);
    expect(l.at(0, 0), lessThan(l.at(2, 1)));
  });

  test('downscales so the long side is at most maxSide', () {
    final l = frameToLuma(bgraFrame(RgbImage.blank(1280, 720)), maxSide: 320)!;
    expect(l.width, 320);
    expect(l.height, 180);
  });
}
