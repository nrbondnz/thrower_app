import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/contrast_normalising_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/target_locator.dart';

const boundaries = [0.2, 0.4, 0.6, 0.8];

/// [image] with every channel mapped through `v → v * gain + offset`.
RgbImage adjusted(RgbImage image, {double gain = 1, double offset = 0}) {
  final out = RgbImage.blank(image.width, image.height);
  for (var i = 0; i < image.pixels.length; i++) {
    out.pixels[i] = (image.pixels[i] * gain + offset).round().clamp(0, 255);
  }
  return out;
}

class FakeLocator implements TargetLocator {
  FakeLocator(this.results);

  final List<TargetLocateResult> results;
  final seen = <RgbImage>[];

  @override
  TargetLocateResult locate(RgbImage image) {
    seen.add(image);
    return results[seen.length - 1];
  }
}

void main() {
  // A real frame from the app on Android (Samsung SM A065F, 2026-10-08): the
  // A4 printout on an indoor wall, handheld, as the ring finder received it.
  final frame = decodeToRgb(File('test/fixtures/targets/a4-android-frame.jpg').readAsBytesSync())!;

  group('finds the A4 target in a real Android frame', () {
    final cases = <(String, RgbImage)>[
      ('as captured', frame),
      ('at half brightness', adjusted(frame, gain: 0.5)),
      ('at 30% brightness', adjusted(frame, gain: 0.3)),
      ('at half contrast', adjusted(frame, gain: 0.5, offset: 64)),
    ];
    for (final (name, image) in cases) {
      test(name, () {
        final result = buildTargetLocator(boundaries).locate(image);
        expect(result, isA<TargetFound>(), reason: result is TargetNotFound ? result.reason : '');
        final edge = (result as TargetFound).boundaries[0.8]!;
        // Hand-checked on the frame: the target is upper left.
        expect(edge.cx, closeTo(140, 15));
        expect(edge.cy, closeTo(222, 15));
      });
    }
  });

  group('normaliseContrast', () {
    test('stretches a dim image to the full range, keeping hue', () {
      final dim = RgbImage.blank(100, 1);
      for (var x = 0; x < 100; x++) {
        dim.setPixel(x, 0, 20 + x, 10 + x ~/ 2, 10);
      }
      final out = normaliseContrast(dim);
      var maxRed = 0;
      for (var x = 0; x < 100; x++) {
        if (out.red(x, 0) > maxRed) maxRed = out.red(x, 0);
        // Red stays above green stays above or equal blue.
        expect(out.red(x, 0), greaterThanOrEqualTo(out.green(x, 0)));
        expect(out.green(x, 0), greaterThanOrEqualTo(out.blue(x, 0)));
      }
      expect(maxRed, 255);
    });

    test('leaves a full-range image unchanged', () {
      final img = RgbImage.blank(2, 1)
        ..setPixel(0, 0, 0, 0, 0)
        ..setPixel(1, 0, 255, 255, 255);
      expect(identical(normaliseContrast(img), img), isTrue);
    });

    test('leaves a flat image unchanged (nothing to stretch)', () {
      final img = RgbImage.blank(4, 4);
      expect(identical(normaliseContrast(img), img), isTrue);
    });
  });

  group('ContrastNormalisingLocator', () {
    const ring = Ellipse(cx: 1, cy: 1, semiMajor: 1, semiMinor: 1, angle: 0);
    final found = TargetFound(boundaries: {0.8: ring}, outer: ring, confidence: 0.9, boundaryPoints: {});
    final dim = adjusted(frame, gain: 0.5);

    test('uses the image as it is when that works (no stretch)', () {
      final inner = FakeLocator([found]);
      expect(ContrastNormalisingLocator(inner).locate(dim), found);
      expect(inner.seen, hasLength(1));
      expect(identical(inner.seen.single, dim), isTrue);
    });

    test('tries a stretched copy when the image as it is fails', () {
      final inner = FakeLocator([const TargetNotFound('No two-colour ring pattern found'), found]);
      expect(ContrastNormalisingLocator(inner).locate(dim), found);
      expect(inner.seen, hasLength(2));
      expect(identical(inner.seen.last, dim), isFalse);
    });

    test('when both fail, keeps the result that has an attempt to look closer at', () {
      final attempt = TargetNotFound('Ring centres disagree', attempted: {0.8: ring});
      final inner = FakeLocator([const TargetNotFound('nothing'), attempt]);
      expect(ContrastNormalisingLocator(inner).locate(dim), attempt);
    });
  });
}
