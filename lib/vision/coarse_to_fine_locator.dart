import 'dart:math' as math;

import 'colour_ring_locator.dart';
import 'contrast_normalising_locator.dart';
import 'ellipse.dart';
import 'rgb_image.dart';
import 'target_locator.dart';

/// The ring finder to use everywhere: [ColourRingLocator] wrapped in
/// [CoarseToFineLocator].
TargetLocator buildTargetLocator(List<double> boundaryRadii) => CoarseToFineLocator(
      ContrastNormalisingLocator(ColourRingLocator(boundaryRadii: boundaryRadii)),
      retry: ContrastNormalisingLocator(ColourRingLocator(boundaryRadii: boundaryRadii, workingSize: 1200)),
    );

/// Find roughly, then look closely. From the side of the throwing line the
/// board fills only a small part of the frame (about 1/6 of the width on a
/// phone's main camera at 2 m), so after [inner] downscales the whole image
/// the bull is a few pixels across and knife handles swamp the rings.
///
/// 1. Run [inner] on the whole image (it downscales) for a rough position.
///    Its rejected attempt is enough when it fails.
/// 2. Crop around that position from the full-resolution image ([margin] ×
///    the target's radius each side, enough for the board's edge) and run
///    [inner] again, so the board gets the detail of the full image.
/// 3. Return the close-up result moved back into whole-image coordinates, or
///    the rough result if the close-up didn't find the target.
class CoarseToFineLocator implements TargetLocator {
  CoarseToFineLocator(this.inner, {this.retry, this.margin = 1.8});

  final TargetLocator inner;

  /// Tried for the rough pass when [inner] finds nothing at all to look closer
  /// at (e.g. a small board whose rings, once downscaled, are too small to
  /// pick out). Typically [inner] with a larger working size.
  final TargetLocator? retry;
  final double margin;

  @override
  TargetLocateResult locate(RgbImage image) {
    var coarse = inner.locate(image);
    if (_region(coarse) == null && retry != null) coarse = retry!.locate(image);
    final region = _region(coarse);
    if (region == null) return coarse;

    final half = region.semiMajor * margin;
    final x0 = math.max(0, (region.cx - half).floor()), y0 = math.max(0, (region.cy - half).floor());
    final x1 = math.min(image.width, (region.cx + half).ceil()), y1 = math.min(image.height, (region.cy + half).ceil());
    final w = x1 - x0, h = y1 - y0;
    // No gain if the crop is (nearly) the whole image, or degenerate.
    if (w < 16 || h < 16 || (w > image.width * 0.9 && h > image.height * 0.9)) return coarse;

    final fine = _moved(inner.locate(image.crop(x0, y0, w, h)), x0.toDouble(), y0.toDouble());
    if (fine is TargetFound) return fine;
    return coarse is TargetFound ? coarse : fine;
  }

  /// Where the target roughly is, as its outer ellipse (normalised radius 1).
  static Ellipse? _region(TargetLocateResult result) {
    switch (result) {
      case TargetFound(:final outer):
        return outer;
      case TargetNotFound(:final attempted):
        if (attempted.isEmpty) return null;
        final r = attempted.keys.reduce(math.max);
        return attempted[r]!.scaled(1 / r);
    }
  }

  static TargetLocateResult _moved(TargetLocateResult r, double dx, double dy) {
    List<Point2> pts(List<Point2> ps) => [for (final p in ps) Point2(p.x + dx, p.y + dy)];
    return switch (r) {
      TargetFound(:final boundaries, :final outer, :final confidence, :final boundaryPoints) => TargetFound(
          boundaries: {for (final e in boundaries.entries) e.key: e.value.translated(dx, dy)},
          outer: outer.translated(dx, dy),
          confidence: confidence,
          boundaryPoints: {for (final e in boundaryPoints.entries) e.key: pts(e.value)},
        ),
      TargetNotFound(:final reason, :final attempted, :final attemptedPoints) => TargetNotFound(
          reason,
          attempted: {for (final e in attempted.entries) e.key: e.value.translated(dx, dy)},
          attemptedPoints: {for (final e in attemptedPoints.entries) e.key: pts(e.value)},
        ),
    };
  }
}
