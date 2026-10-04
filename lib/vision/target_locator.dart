import 'ellipse.dart';
import 'rgb_image.dart';

/// Finds the target's painted rings in an image. Implementations can be
/// swapped (pure Dart colour segmentation now; OpenCV or a trained model later)
/// without touching scoring or UI. See Design Decisions → Target Locating.
abstract interface class TargetLocator {
  TargetLocateResult locate(RgbImage image);
}

sealed class TargetLocateResult {
  const TargetLocateResult();
}

class TargetFound extends TargetLocateResult {
  const TargetFound({
    required this.boundaries,
    required this.outer,
    required this.confidence,
    required this.boundaryPoints,
  });

  /// One fitted ellipse per ring boundary inside the target, keyed by the
  /// boundary's normalised radius (e.g. 0.2 for the edge of the bull).
  final Map<double, Ellipse> boundaries;

  /// The outer edge of the outermost scoring ring (normalised radius 1),
  /// extrapolated from the inner boundaries: on a real board the outer ring's
  /// edge is often the board's own irregular edge, so it isn't fitted directly.
  final Ellipse outer;

  /// 0–1: the share of ray samples that agreed with the fitted ellipses.
  final double confidence;

  /// The edge points each ellipse was fitted to, for debug overlays.
  final Map<double, List<Point2>> boundaryPoints;
}

class TargetNotFound extends TargetLocateResult {
  const TargetNotFound(this.reason, {this.attempted = const {}, this.attemptedPoints = const {}});

  final String reason;

  /// Ellipses fitted before the result was rejected, if any (for debug overlays).
  final Map<double, Ellipse> attempted;
  final Map<double, List<Point2>> attemptedPoints;
}
