import 'dart:math' as math;

import 'target_calibration.dart';

/// How far to zoom the camera in on a found target, and what limited it.
class ZoomPlan {
  const ZoomPlan(this.zoom, {required this.offCentre});

  /// 1 means don't zoom.
  final double zoom;

  /// The board's distance from the picture's centre stopped the zoom short
  /// of filling the frame (the camera zooms about the centre, so centring
  /// the phone on the board would allow more).
  final bool offCentre;
}

/// The zoom (from the 1× picture [calibration] was found in) that makes the
/// board fill [fill] of the picture's shorter side, as long as the board, with
/// [margin] × its radius around it, stays in the picture, up to [maxZoom].
///
/// [fill] is below 1 to leave room for knife handles sticking out past the
/// board and for small camera nudges, which zooming makes bigger. Gains under
/// [minGain] aren't worth refinding the rings for, so they give 1.
ZoomPlan zoomToFit(
  TargetCalibration calibration, {
  required double maxZoom,
  double fill = 0.7,
  double margin = 0.3,
  double minGain = 1.2,
}) {
  final e = calibration.outer;
  final c = math.cos(e.angle), s = math.sin(e.angle);
  // Half the outer ellipse's width and height.
  final halfW = math.sqrt(math.pow(e.semiMajor * c, 2) + math.pow(e.semiMinor * s, 2));
  final halfH = math.sqrt(math.pow(e.semiMajor * s, 2) + math.pow(e.semiMinor * c, 2));
  final w = calibration.imageWidth.toDouble(), h = calibration.imageHeight.toDouble();

  final fillZoom = fill * math.min(w, h) / (2 * math.max(halfW, halfH));

  // Zooming by z moves a point at distance d from the centre to z·d, so the
  // padded board's furthest side must stay within half the picture.
  final pad = margin * math.max(e.semiMajor, e.semiMinor);
  final reachX = math.max((e.cx - w / 2).abs() + halfW + pad, 1e-9);
  final reachY = math.max((e.cy - h / 2).abs() + halfH + pad, 1e-9);
  final positionZoom = math.min(w / 2 / reachX, h / 2 / reachY);

  final zoom = [fillZoom, positionZoom, maxZoom].reduce(math.min);
  return ZoomPlan(zoom < minGain ? 1 : zoom, offCentre: positionZoom < fillZoom && positionZoom < maxZoom);
}
