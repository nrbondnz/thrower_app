import 'dart:math' as math;

import '../camera/cropped_camera.dart';
import '../camera/target_camera.dart';
import '../vision/target_calibration.dart';

/// One board's own square of [camera]'s picture, as a camera of its own,
/// with the board's calibration inside it: Quick draw and two-target Play
/// watch each board with the single-board throw detection on its crop.
/// [cropRadii] is the square's side in board radii: the watched region is 3
/// radii wide (`WatchRegion.fromCalibration`), so 4 leaves room around it;
/// for a long board (wider than 2:1, e.g. a four-cornered one), the square
/// is widened to hold that region along its longest side. The square is
/// kept inside the picture.
/// The watched region's margin round the board (`WatchRegion.fromCalibration`).
const watchMargin = 1.5;

({CroppedCamera camera, TargetCalibration calibration}) cropToBoard(TargetCamera camera, TargetCalibration board,
    {double cropRadii = 4}) {
  final shape = board.shape, centre = shape.centre;
  final (:halfWidth, :halfHeight) = shape.halfExtent;
  final wanted = math.max(cropRadii * shape.meanRadius, 2 * watchMargin * math.max(halfWidth, halfHeight));
  final side = math.min(wanted.round(), math.min(board.imageWidth, board.imageHeight)) & ~1;
  final x = math.max(0, math.min((centre.x - side / 2).round(), board.imageWidth - side));
  final y = math.max(0, math.min((centre.y - side / 2).round(), board.imageHeight - side));
  final crop = CroppedCamera(camera, x: x, y: y, width: side, height: side);
  return (camera: crop, calibration: board.within(crop.x, crop.y, crop.width, crop.height));
}
