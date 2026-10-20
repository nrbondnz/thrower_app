import 'dart:math' as math;

import '../vision/ellipse.dart';
import '../vision/target_calibration.dart';

/// Quick draw's **drawn** boards (Mark, 2026-10-21: "draw his finger round
/// the board as a single hit point, not worrying about rings for scoring,
/// just relying on hit time in the area he draws"). The loop the finger drew
/// round a board, in the upright picture's pixels ([imageWidth] ×
/// [imageHeight]), as a board: the ellipse that best fits the loop (boards
/// are round, and the throw detection, the board's crop and the outline
/// editor all work on an ellipse). Its rings are the same ellipse scaled
/// (0.2 … 0.8): the entry-point code needs a centre ring, but a drawn board
/// is never scored (`QuickDrawTargets.areas`). Null if the loop is too short
/// or too small to be a board, or too flat to be a fair fit.
TargetCalibration? areaBoard(List<Point2> loop, {required int imageWidth, required int imageHeight}) {
  if (loop.length < minLoopPoints) return null;
  final outer = fitEllipse(loop);
  if (outer == null || !outer.semiMajor.isFinite || !outer.semiMinor.isFinite) return null;
  final shorter = math.min(imageWidth, imageHeight);
  final small = math.min(outer.semiMajor, outer.semiMinor), large = math.max(outer.semiMajor, outer.semiMinor);
  if (small < shorter * minAreaRadius || large > shorter) return null;
  if (small < large * minRoundness) return null;
  return TargetCalibration(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    boundaries: {
      for (final r in const [0.2, 0.4, 0.6, 0.8]) r: outer.scaled(r),
    },
    outer: outer,
  );
}

/// See [areaBoard]: the fewest points a drawn loop needs, the smallest
/// board radius (a share of the picture's shorter side), and the flattest
/// ellipse accepted (minor ÷ major: a board seen from the side is ~0.5).
const minLoopPoints = 8;
const minAreaRadius = 0.03;
const minRoundness = 0.35;
