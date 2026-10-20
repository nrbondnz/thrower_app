import 'package:flutter/foundation.dart';

import '../camera/target_camera.dart';
import '../vision/ellipse.dart';
import '../vision/frame_to_rgb.dart';
import '../vision/tapped_target_locator.dart';
import '../vision/target_calibration.dart';
import '../vision/target_locator.dart';

/// Quick draw's boards, in the order they were tapped: Player 1's first.
/// Locked once both are found; throws are then timed and scored against them.
/// A board drawn round by finger ([areas]: Mark, 2026-10-21) is timed only,
/// never scored.
class QuickDrawTargets {
  const QuickDrawTargets({this.boards = const [], this.locked = false, this.areas = const {}});

  /// Two players, one board each.
  static const players = 2;

  final List<TargetCalibration> boards;
  final bool locked;

  bool get complete => boards.length == players;

  /// The players (indexes) whose board was drawn round (`areaBoard`), not
  /// found by its rings.
  final Set<int> areas;
}

/// Finds the board at [tap] on the camera's next frame. [tap] is a fraction
/// of the upright picture's width and height (0–1 each way), so it doesn't
/// depend on the camera's resolution or which way its sensor faces.
typedef TapLocator = Future<TappedTargetsResult> Function(TargetCamera camera, Point2 tap);

/// The app's [TapLocator]: [locateTappedInFrame] in a background isolate.
Future<TappedTargetsResult> locateAtTap(TargetCamera camera, Point2 tap, List<double> boundaryRadii) async {
  final frame = await camera.frames().first;
  return compute(locateTappedInFrame, (frame, camera.uprightRotation, boundaryRadii, [tap]));
}

/// The size of the picture a board drawn round by finger is in: the
/// camera's next frame turned upright, no larger than [locateTappedInFrame]'s
/// (so drawn and tapped boards share one picture size).
typedef PictureSizer = Future<(int, int)> Function(TargetCamera camera);

/// The app's [PictureSizer].
Future<(int, int)> uprightPictureSize(TargetCamera camera) async =>
    uprightSizeOf(await camera.frames().first, maxSide: 1920, rotation: camera.uprightRotation);

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
