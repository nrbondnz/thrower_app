// Shared by the render tools: the reference board (docs/thrower/reference/
// target-example.png) as a texture, its measured painted rings, and its size.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/photo_board_texture.dart';
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/synthetic_scene.dart';
import 'package:thrower_app/vision/target_locator.dart';

/// Camera 2 m from the board (Nigel, 2026-10-08), off to the thrower's right
/// at 45°, at the board's height, aimed at its centre.
const camera = Vec3(1.414, 0.0, 1.414);

/// Nigel's boards: about 75–85 cm across (2026-10-08). The rings are sized
/// from the photo's proportions (they reach ~0.89 of the way to the bark).
const boardDiameterMetres = 0.80;

class ReferenceBoard {
  ReferenceBoard._(this.texture, this.paintedRingRadii, this.targetRadius, this.boundaries);

  final PhotoBoardTexture texture;

  /// Painted ring edges (normalised, measured on the photo relative to the
  /// 0.8 edge; hand-painted, so not the ideal 0.2 / 0.4 / 0.6), then 1.0.
  final List<double> paintedRingRadii;

  /// Metres of normalised radius 1 for a [boardDiameterMetres] board.
  final double targetRadius;

  /// Ideal ring boundaries inside the target (0.2 … 0.8).
  final List<double> boundaries;

  static ReferenceBoard build() {
    final model = TargetModel.ikthof();
    final boundaries = [for (final r in model.rings.take(model.rings.length - 1)) r.outerRadius];
    final photo = decodeToRgb(File('docs/thrower/reference/target-example.png').readAsBytesSync())!;
    final fit = buildTargetLocator(boundaries).locate(photo);
    if (fit is! TargetFound) {
      throw StateError('Ring finder failed on the reference photo: ${(fit as TargetNotFound).reason}');
    }
    // Scale per image axis from the 0.8 ring edge's extent (the photo is
    // nearly straight on, so this undoes its slight squash without rotating).
    final edge = fit.boundaries[0.8]!;
    final c = math.cos(edge.angle), s = math.sin(edge.angle);
    final halfWidth = math.sqrt(math.pow(edge.semiMajor * c, 2) + math.pow(edge.semiMinor * s, 2));
    final halfHeight = math.sqrt(math.pow(edge.semiMajor * s, 2) + math.pow(edge.semiMinor * c, 2));
    final texture = PhotoBoardTexture(
      photo,
      centreX: edge.cx,
      centreY: edge.cy,
      pixelsPerUnitX: halfWidth / 0.8,
      pixelsPerUnitY: halfHeight / 0.8,
    );
    double meanAxis(Ellipse e) => (e.semiMajor + e.semiMinor) / 2;
    final painted = [
      for (final r in boundaries) r == 0.8 ? 0.8 : 0.8 * meanAxis(fit.boundaries[r]!) / meanAxis(edge),
      1.0,
    ];
    return ReferenceBoard._(texture, painted, boardDiameterMetres / 2 / texture.meanEdge, boundaries);
  }
}

void saveJpg(RgbImage rgb, String path, {int quality = 90}) {
  final out = img.Image(width: rgb.width, height: rgb.height);
  for (var y = 0; y < rgb.height; y++) {
    for (var x = 0; x < rgb.width; x++) {
      out.setPixelRgb(x, y, rgb.red(x, y), rgb.green(x, y), rgb.blue(x, y));
    }
  }
  File(path).writeAsBytesSync(img.encodeJpg(out, quality: quality));
}
