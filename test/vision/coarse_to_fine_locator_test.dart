import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/target_locator.dart';

const boundaries = [0.2, 0.4, 0.6, 0.8];

/// A locator that returns scripted results and records what it was given.
class FakeLocator implements TargetLocator {
  FakeLocator(this.results);

  final List<TargetLocateResult> results;
  final seen = <(int, int)>[];

  @override
  TargetLocateResult locate(RgbImage image) {
    seen.add((image.width, image.height));
    return results[seen.length - 1];
  }
}

TargetFound found(Ellipse outer, {double confidence = 0.9}) => TargetFound(
      boundaries: {0.8: outer.scaled(0.8)},
      outer: outer,
      confidence: confidence,
      boundaryPoints: {0.8: [Point2(outer.cx, outer.cy)]},
    );

void main() {
  group('CoarseToFineLocator', () {
    const rough = Ellipse(cx: 500, cy: 300, semiMajor: 50, semiMinor: 40, angle: 0);
    const close = Ellipse(cx: 90, cy: 90, semiMajor: 49, semiMinor: 41, angle: 0);

    test('looks again at a crop around the rough find, at full resolution', () {
      final inner = FakeLocator([found(rough), found(close)]);
      CoarseToFineLocator(inner).locate(RgbImage.blank(1600, 1200));
      // 1.8 × radius 50 each side of (500, 300).
      expect(inner.seen, [(1600, 1200), (180, 180)]);
    });

    test('moves the close-up result back into whole-image coordinates', () {
      final inner = FakeLocator([found(rough), found(close)]);
      final result = CoarseToFineLocator(inner).locate(RgbImage.blank(1600, 1200)) as TargetFound;
      expect(result.outer.cx, 410 + 90);
      expect(result.outer.cy, 210 + 90);
      expect(result.boundaries[0.8]!.cx, 500);
      expect(result.boundaryPoints[0.8]!.single.x, 500);
    });

    test("uses a rough attempt's position even when the rough pass failed", () {
      final inner = FakeLocator([
        TargetNotFound('Ring centres disagree', attempted: {0.8: rough.scaled(0.8)}),
        found(close),
      ]);
      final result = CoarseToFineLocator(inner).locate(RgbImage.blank(1600, 1200));
      expect(result, isA<TargetFound>());
      expect(inner.seen.last, (180, 180));
    });

    test('keeps the rough result if the close-up fails', () {
      final inner = FakeLocator([found(rough), const TargetNotFound('nope')]);
      final result = CoarseToFineLocator(inner).locate(RgbImage.blank(1600, 1200)) as TargetFound;
      expect(result.outer.cx, 500);
    });

    test('retries the rough pass (e.g. at a larger size) when it finds nothing at all', () {
      final inner = FakeLocator([const TargetNotFound('No two-colour ring pattern found'), found(close)]);
      final retry = FakeLocator([TargetNotFound('Ring centres disagree', attempted: {0.8: rough.scaled(0.8)})]);
      final result = CoarseToFineLocator(inner, retry: retry).locate(RgbImage.blank(1600, 1200));
      expect(retry.seen, [(1600, 1200)]);
      expect(inner.seen.last, (180, 180));
      expect(result, isA<TargetFound>());
    });

    test('does not retry when the rough pass gave a position', () {
      final inner = FakeLocator([found(rough), found(close)]);
      final retry = FakeLocator([]);
      CoarseToFineLocator(inner, retry: retry).locate(RgbImage.blank(1600, 1200));
      expect(retry.seen, isEmpty);
    });

    test('stops after the rough pass when there is nothing to look closer at', () {
      final inner = FakeLocator([const TargetNotFound('No two-colour ring pattern found')]);
      expect(CoarseToFineLocator(inner).locate(RgbImage.blank(1600, 1200)), isA<TargetNotFound>());
      expect(inner.seen, hasLength(1));
    });

    test('skips the close-up when the target already fills the image', () {
      final inner = FakeLocator([found(const Ellipse(cx: 300, cy: 300, semiMajor: 280, semiMinor: 280, angle: 0))]);
      CoarseToFineLocator(inner).locate(RgbImage.blank(600, 600));
      expect(inner.seen, hasLength(1));
    });
  });

  group('finds the rings in camera views from beside the throwing line', () {
    // Rendered by tool/render_camera_views.dart: the reference board seen from
    // 2 m to the side and 2 m out, with known ring edges (truth.json).
    final truth = jsonDecode(File('test/fixtures/camera-views/truth.json').readAsStringSync()) as Map<String, dynamic>;
    for (final name in truth.keys) {
      test(name, () {
        final image = decodeToRgb(File('test/fixtures/camera-views/$name').readAsBytesSync())!;
        final result = buildTargetLocator(boundaries).locate(image);
        expect(result, isA<TargetFound>(), reason: result is TargetNotFound ? result.reason : '');
        final rings = (result as TargetFound).boundaries;
        final edges = (truth[name] as Map<String, dynamic>)['ringEdgePixels'] as Map<String, dynamic>;
        // Misses are measured as a share of the target's size (the 0.8 edge),
        // not of each ring's own radius: the true edges are circles at the
        // painted rings' average size, but the hand-sprayed bull isn't a true
        // circle, and at 1× it is only ~20 px across.
        double size(Ellipse e) => (e.semiMajor + e.semiMinor) / 2;
        final scale = size(rings[0.8]!);
        for (final r in boundaries) {
          final ring = rings[r]!;
          final points = [for (final p in edges['$r'] as List) Point2((p[0] as num).toDouble(), (p[1] as num).toDouble())];
          final misses = [for (final p in points) (ring.normalisedRadius(p) - 1).abs() * size(ring) / scale];
          final worst = misses.reduce((a, b) => a > b ? a : b);
          final mean = misses.reduce((a, b) => a + b) / misses.length;
          final where = 'ring edge $r: worst ${(worst * 100).toStringAsFixed(1)}%, mean ${(mean * 100).toStringAsFixed(1)}%';
          expect(worst, lessThan(0.05), reason: where);
          // The blotchy bull alone sits near 2% on average (2.0% at 2× with
          // two knives); every other edge is well under.
          expect(mean, lessThan(0.025), reason: where);
        }
      });
    }
  });
}
