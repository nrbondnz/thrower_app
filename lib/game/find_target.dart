import 'package:flutter/foundation.dart';

import '../camera/target_camera.dart';
import '../vision/locate_in_frame.dart';
import '../vision/target_calibration.dart';
import '../vision/target_locator.dart';
import '../vision/zoom_to_fit.dart';

/// What "Find target" ended with: the ring finder's result, in the picture at
/// the camera's final [zoom], and whether the board's position held the zoom
/// back ([ZoomPlan.offCentre]).
class FindResult {
  const FindResult(this.found, {required this.zoom, required this.offCentre});

  final FrameLocateResult found;
  final double zoom;
  final bool offCentre;
}

/// Runs the ring finder on the camera's next frame.
typedef FrameLocator = Future<FrameLocateResult> Function(TargetCamera camera);

/// Find target: search the whole picture at 1×, zoom the camera in on the
/// board ([zoomToFit]), then find the rings again in the closer view. If they
/// can't be found zoomed in (or the camera won't zoom), go back to 1× and keep
/// the first result. [settle] is how long frames take to show a new zoom.
Future<FindResult> findTarget(
  TargetCamera camera,
  FrameLocator locate, {
  Duration settle = const Duration(milliseconds: 500),
}) async {
  Future<bool> zoomTo(double level) async {
    if (camera.zoom == level) return true;
    try {
      await camera.setZoom(level);
    } on Exception catch (e) {
      debugPrint('Zoom to $level× failed: $e');
      return false;
    }
    await Future<void>.delayed(settle);
    return true;
  }

  if (!await zoomTo(1)) return FindResult(await locate(camera), zoom: camera.zoom, offCentre: false);
  final wide = await locate(camera);
  final rings = wide.result;
  if (rings is! TargetFound) return FindResult(wide, zoom: 1, offCentre: false);

  final plan = zoomToFit(
    TargetCalibration(
      imageWidth: wide.imageWidth,
      imageHeight: wide.imageHeight,
      boundaries: rings.boundaries,
      outer: rings.outer,
    ),
    maxZoom: camera.maxZoom,
  );
  if (plan.zoom > 1 && await zoomTo(plan.zoom)) {
    final closer = await locate(camera);
    if (closer.result is TargetFound) return FindResult(closer, zoom: camera.zoom, offCentre: plan.offCentre);
    await zoomTo(1);
  }
  return FindResult(wide, zoom: camera.zoom, offCentre: plan.offCentre);
}
