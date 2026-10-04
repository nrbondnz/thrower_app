import 'camera_frame.dart';

/// Where the vision layer gets frames from: the live camera on a phone, or
/// recorded frames in tests.
abstract interface class CameraSource {
  /// Broadcast stream of frames. Frames only flow while something listens.
  Stream<CameraFrame> frames();
}
