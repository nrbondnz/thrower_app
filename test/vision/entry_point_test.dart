import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/entry_point.dart';
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/target_locator.dart';
import 'package:thrower_app/vision/target_mapping.dart';

const boundaries = [0.2, 0.4, 0.6, 0.8];

RgbImage load(String path) => decodeToRgb(File('test/fixtures/entry/$path').readAsBytesSync())!;

void main() {
  final cases = (jsonDecode(File('test/fixtures/entry/cases.json').readAsStringSync()) as Map<String, dynamic>)
      .cast<String, Map<String, dynamic>>();

  group('finds the blade entry point on rendered throws', () {
    for (final MapEntry(key: name, value: c) in cases.entries) {
      test(name, () {
        final before = load(c['before'] as String), after = load(c['after'] as String);
        final found = buildTargetLocator(boundaries).locate(before) as TargetFound;
        final calibration = TargetCalibration(
          imageWidth: before.width,
          imageHeight: before.height,
          boundaries: found.boundaries,
          outer: found.outer,
        );
        final estimate = GeometricEntryEstimator().estimate(before, after, calibration);
        expect(estimate, isNotNull);

        final truth = (c['entryPixel'] as List).cast<num>();
        final error = math.sqrt(math.pow(estimate!.point.x - truth[0], 2) + math.pow(estimate.point.y - truth[1], 2));
        final radius = (calibration.outer.semiMajor + calibration.outer.semiMinor) / 2;
        final score = TargetModel.ikthof().scoreAt(TargetMapping(calibration).toTarget(estimate.point));
        // ignore: avoid_print
        print('$name: entry ${estimate.point} vs truth (${truth[0]}, ${truth[1]}): '
            '${error.toStringAsFixed(1)} px = ${(error / radius * 100).toStringAsFixed(1)}% of the target radius; '
            'score $score (true ${c['score']}); knife ${estimate.knifePixels} px');

        // Within 4% of the target radius (~1.5 cm on an 80 cm board).
        expect(error / radius, lessThan(0.04), reason: '${error.toStringAsFixed(1)} px off');
        expect(score, c['score']);
      });
    }
  });

  test('the outward direction points away from the camera side (camera on the right → left)', () {
    final before = load(cases['throw-stick-ring4']!['before'] as String);
    final found = buildTargetLocator(boundaries).locate(before) as TargetFound;
    final out = outwardDirection(TargetCalibration(
      imageWidth: before.width,
      imageHeight: before.height,
      boundaries: found.boundaries,
      outer: found.outer,
    ));
    expect(out.x, lessThan(0));
    expect(Point2(out.x, out.y).x.abs(), greaterThan(out.y.abs()));
  });
}
