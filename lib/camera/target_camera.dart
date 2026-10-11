import 'camera_source.dart';

/// A camera pointed at the target: the phone's live camera, or a recording
/// played back as if it were one (Live test). The calibration and Play
/// screens, and throw detection, work with either.
abstract interface class TargetCamera implements CameraSource {
  /// Clockwise rotation (0, 90, 180 or 270) that turns this camera's frames
  /// upright (see `frameRotation`).
  int get uprightRotation;

  Future<void> dispose();
}
