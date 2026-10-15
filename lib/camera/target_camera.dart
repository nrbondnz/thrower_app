import 'camera_source.dart';

/// A camera pointed at the target: the phone's live camera, or a recording
/// played back as if it were one (Live test). The calibration and Play
/// screens, and throw detection, work with either.
abstract interface class TargetCamera implements CameraSource {
  /// Clockwise rotation (0, 90, 180 or 270) that turns this camera's frames
  /// upright (see `frameRotation`).
  int get uprightRotation;

  /// The smallest brightness difference between two frames (0–255) that can
  /// be a real change rather than how this source makes its frames: a live
  /// camera's sensor noise is learned on top, but compressed video also
  /// re-encodes blocks of the picture that differ by up to ~20 levels.
  int get minChange;

  /// The furthest this camera can zoom in (1 = it can't).
  double get maxZoom;

  /// The time now on the clock this camera stamps its frames with
  /// (`CameraFrame.timestamp`), so other moments (Quick draw's "go") can be
  /// compared with frames.
  Duration get now;

  /// The current zoom: 1 is the full picture, 2 shows the middle half of it
  /// (each way) filling the frame.
  double get zoom;

  /// Zooms the camera itself, about the centre of the picture, clamped to
  /// 1 … [maxZoom]. On a phone this is the lens or a sensor crop made before
  /// the frame is scaled down, so a zoomed board gets more real detail, not
  /// just bigger pixels.
  Future<void> setZoom(double level);

  Future<void> dispose();
}
