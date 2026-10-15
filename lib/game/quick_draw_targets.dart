import 'package:flutter/foundation.dart';

import '../camera/target_camera.dart';
import '../vision/ellipse.dart';
import '../vision/tapped_target_locator.dart';
import '../vision/target_calibration.dart';
import '../vision/target_locator.dart';

/// Quick draw's boards, in the order they were tapped: Player 1's first.
/// Locked once both are found; throws are then timed and scored against them.
class QuickDrawTargets {
  const QuickDrawTargets({this.boards = const [], this.locked = false});

  /// Two players, one board each.
  static const players = 2;

  final List<TargetCalibration> boards;
  final bool locked;

  bool get complete => boards.length == players;
}

/// Finds the board at [tap] (upright image pixels) on the camera's next frame.
typedef TapLocator = Future<TappedTargetsResult> Function(TargetCamera camera, Point2 tap);

/// The app's [TapLocator]: [locateTappedInFrame] in a background isolate.
Future<TappedTargetsResult> locateAtTap(TargetCamera camera, Point2 tap, List<double> boundaryRadii) async {
  final frame = await camera.frames().first;
  return compute(locateTappedInFrame, (frame, camera.uprightRotation, boundaryRadii, [tap]));
}

/// The board found at a tap, as a calibration; null if none was found.
TargetCalibration? boardAt(TappedTargetsResult result) => switch (result.boards.single) {
      TargetFound(:final boundaries, :final outer) => TargetCalibration(
          imageWidth: result.imageWidth,
          imageHeight: result.imageHeight,
          boundaries: boundaries,
          outer: outer,
        ),
      TargetNotFound() => null,
    };
