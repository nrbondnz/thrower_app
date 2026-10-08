import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../camera/camera_frame.dart';
import '../camera/live_camera.dart';
import '../vision/entry_point.dart';
import '../vision/frame_to_rgb.dart';
import '../vision/luma_image.dart';
import '../vision/rgb_image.dart';
import '../vision/motion_detector.dart';
import '../vision/target_calibration.dart';
import '../vision/throw_classifier.dart';

/// While the target is locked: watches the board in the live stream and shows
/// the motion detector's state and its last episode. (Task 2's check; the
/// play screen will build on it.)
class WatchStatus extends StatefulWidget {
  const WatchStatus({super.key, required this.camera, required this.calibration, this.onKnifeEntry});

  final LiveCamera camera;
  final TargetCalibration calibration;

  /// Called when a stuck knife's blade entry has been found (image pixel in
  /// the calibration's upright frame), or with null if it couldn't be.
  final ValueChanged<EntryEstimate?>? onKnifeEntry;

  /// Frames are processed at most this often (the stream may be 30 fps).
  static const interval = Duration(milliseconds: 60);

  /// How often a full-resolution "before" picture is kept while still.
  static const beforeRefresh = Duration(seconds: 1);

  @override
  State<WatchStatus> createState() => _WatchStatusState();
}

class _WatchStatusState extends State<WatchStatus> {
  late MotionDetector _detector;
  StreamSubscription<CameraFrame>? _frames;
  Duration? _lastProcessed;
  WatchState _state = WatchState.watching;
  MotionEpisode? _last;
  ThrowOutcome? _outcome;

  /// Full-resolution, upright picture of the still board (refreshed while
  /// watching), and whether the next frame should be taken as the "after".
  RgbImage? _fullBefore;
  Duration? _fullBeforeAt;
  var _capturing = false;
  var _wantAfter = false;

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
    if (_wantAfter && !_capturing) {
      _wantAfter = false;
      _findEntry(frame);
    }
    final last = _lastProcessed;
    if (last != null && frame.timestamp - last < WatchStatus.interval) return;
    _lastProcessed = frame.timestamp;
    final rotation = widget.camera.uprightRotation;
    final luma = frameToLuma(frame, rotation: rotation);
    if (luma == null) return;
    final update = _detector.add(luma, frame.timestamp);
    if (!mounted) return;

    // Keep a fresh full-resolution "before" while the board is still.
    final keptAt = _fullBeforeAt;
    if (update.state == WatchState.watching &&
        !_capturing &&
        (keptAt == null || frame.timestamp - keptAt >= WatchStatus.beforeRefresh)) {
      _capturing = true;
      _fullBeforeAt = frame.timestamp;
      compute(uprightFullRgb, (frame, rotation)).then((rgb) {
        _capturing = false;
        if (rgb != null) _fullBefore = rgb;
      });
    }

    final finished = update.finished;
    if (update.state != _state || finished != null) {
      setState(() {
        _state = update.state;
        if (finished != null) {
          _last = finished;
          _outcome = classifyThrow(finished, widget.calibration);
          if (_outcome!.kind == ThrowOutcomeKind.stuck) _wantAfter = true;
        }
      });
    }
  }

  /// Full-resolution "after" → the blade's entry, off the UI thread. The
  /// after picture (with the new knife) becomes the next "before".
  Future<void> _findEntry(CameraFrame frame) async {
    final before = _fullBefore;
    if (before == null) {
      widget.onKnifeEntry?.call(null);
      return;
    }
    _capturing = true;
    final after = await compute(uprightFullRgb, (frame, widget.camera.uprightRotation));
    _capturing = false;
    if (after == null || !mounted) return;
    _fullBefore = after;
    _fullBeforeAt = frame.timestamp;
    final entry = await compute(findKnifeEntry, (before, after, widget.calibration));
    if (mounted) widget.onKnifeEntry?.call(entry);
  }

  @override
  void dispose() {
    _frames?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      watchStatusText(_state, _last, outcome: _outcome),
      key: const Key('watchStatus'),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white70),
    );
  }
}

/// For `compute`: a camera frame as an upright, full-resolution RGB image
/// (the same size the calibration was made at).
RgbImage? uprightFullRgb((CameraFrame, int) input) => frameToRgb(input.$1, rotation: input.$2, maxSide: 1920);

/// For `compute`: the new knife's blade entry between two full-resolution
/// pictures.
EntryEstimate? findKnifeEntry((RgbImage, RgbImage, TargetCalibration) input) =>
    GeometricEntryEstimator().estimate(input.$1, input.$2, input.$3);

/// The detector's state, what the last episode was, and its numbers.
String watchStatusText(WatchState state, MotionEpisode? last, {ThrowOutcome? outcome}) {
  final now = switch (state) {
    WatchState.watching => 'Board still: watching',
    WatchState.motion => 'Motion',
    WatchState.settling => 'Settling…',
    WatchState.blocked => 'Something is in front of the board',
  };
  if (last == null) return now;
  final what = switch (outcome?.kind) {
    ThrowOutcomeKind.stuck => 'Stuck in the board',
    ThrowOutcomeKind.bounceOut => 'Bounced off (0)',
    ThrowOutcomeKind.boardVisit => 'Someone was at the board',
    ThrowOutcomeKind.sceneChanged => 'The view changed: re-calibrate?',
    null => null,
  };
  final seconds = (last.settled - last.start).inMilliseconds / 1000;
  return '$now\n${what == null ? '' : '$what. '}Last: ${seconds.toStringAsFixed(1)} s of motion, '
      'peak ${(last.peakChange * 100).toStringAsFixed(1)}%, '
      '${(last.changeFromBefore * 100).toStringAsFixed(1)}% changed from before'
      '${last.acceptedNewScene ? ' (accepted as the new view)' : ''}';
}
