/// Frames per second over the last second of frame timestamps.
class FrameRateMeter {
  final _recent = <Duration>[];

  static const _window = Duration(seconds: 1);

  void record(Duration timestamp) {
    _recent.add(timestamp);
    while (timestamp - _recent.first > _window) {
      _recent.removeAt(0);
    }
  }

  int get framesPerSecond => _recent.length;
}
