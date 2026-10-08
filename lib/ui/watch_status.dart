import 'dart:async';

import 'package:flutter/material.dart';

import '../camera/camera_frame.dart';
import '../camera/live_camera.dart';
import '../vision/luma_image.dart';
import '../vision/motion_detector.dart';
import '../vision/target_calibration.dart';

/// While the target is locked: watches the board in the live stream and shows
/// the motion detector's state and its last episode. (Task 2's check; the
/// play screen will build on it.)
class WatchStatus extends StatefulWidget {
  const WatchStatus({super.key, required this.camera, required this.calibration});

  final LiveCamera camera;
  final TargetCalibration calibration;

  /// Frames are processed at most this often (the stream may be 30 fps).
  static const interval = Duration(milliseconds: 60);

  @override
  State<WatchStatus> createState() => _WatchStatusState();
}

class _WatchStatusState extends State<WatchStatus> {
  late MotionDetector _detector;
  StreamSubscription<CameraFrame>? _frames;
  Duration? _lastProcessed;
  WatchState _state = WatchState.watching;
  MotionEpisode? _last;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(WatchStatus old) {
    super.didUpdateWidget(old);
    if (old.calibration != widget.calibration || old.camera != widget.camera) {
      _frames?.cancel();
      _start();
    }
  }

  void _start() {
    _detector = MotionDetector(WatchRegion.fromCalibration(widget.calibration));
    _frames = widget.camera.frames().listen(_onFrame);
  }

  void _onFrame(CameraFrame frame) {
    final last = _lastProcessed;
    if (last != null && frame.timestamp - last < WatchStatus.interval) return;
    _lastProcessed = frame.timestamp;
    final luma = frameToLuma(frame, rotation: widget.camera.uprightRotation);
    if (luma == null) return;
    final update = _detector.add(luma, frame.timestamp);
    if (!mounted) return;
    if (update.state != _state || update.finished != null) {
      setState(() {
        _state = update.state;
        if (update.finished != null) _last = update.finished;
      });
    }
  }

  @override
  void dispose() {
    _frames?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      watchStatusText(_state, _last),
      key: const Key('watchStatus'),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white70),
    );
  }
}

/// The detector's state and last episode, in words.
String watchStatusText(WatchState state, MotionEpisode? last) {
  final now = switch (state) {
    WatchState.watching => 'Board still: watching',
    WatchState.motion => 'Motion',
    WatchState.settling => 'Settling…',
    WatchState.blocked => 'Something is in front of the board',
  };
  if (last == null) return now;
  final seconds = (last.settled - last.start).inMilliseconds / 1000;
  return '$now\nLast: ${seconds.toStringAsFixed(1)} s of motion, peak ${(last.peakChange * 100).toStringAsFixed(1)}%, '
      '${(last.changeFromBefore * 100).toStringAsFixed(1)}% changed from before'
      '${last.acceptedNewScene ? ' (accepted as the new view)' : ''}';
}
