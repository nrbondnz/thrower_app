import 'dart:async';

import 'package:flutter/foundation.dart';

import '../camera/camera_frame.dart';
import '../camera/target_camera.dart';
import '../vision/camera_move.dart';
import '../vision/entry_point.dart';
import '../vision/frame_to_rgb.dart';
import '../vision/luma_image.dart';
import '../vision/motion_detector.dart';
import '../vision/rgb_image.dart';
import '../vision/target_calibration.dart';
import '../vision/throw_classifier.dart';
import 'throw_tracker.dart';
import 'watch_debug_log.dart';

/// Something the watcher decided about a settled episode.
class ThrowEvent {
  const ThrowEvent(this.outcome, this.episode, {this.entry, this.knifeId});

  final ThrowOutcome outcome;
  final MotionEpisode episode;

  /// For a stuck knife: where the blade went in (null if not found).
  final EntryEstimate? entry;

  /// For a stuck knife: a new id for it. For a knife that fell out: the id it
  /// was given when it stuck.
  final int? knifeId;
}

/// Watches the locked target in the live camera stream and turns what happens
/// into [ThrowEvent]s:
/// - brightness frames (~320 px, at most every [interval]) → [MotionDetector];
/// - each settled episode → [classifyThrow], knowing the knives already in the
///   board (so a knife falling out isn't taken for a new one);
/// - for a stuck knife: a full-resolution after picture against the kept
///   before picture → [GeometricEntryEstimator], off the UI thread; or, on a
///   board seen face on ([isFaceOn]), straight from the knife's shape
///   ([faceOnEntry]).
///
/// Knives are remembered until a board visit (someone collecting them).
class ThrowWatcher {
  ThrowWatcher(this.camera, this.calibration, {this.interval = const Duration(milliseconds: 60)})
      : _detector = MotionDetector(WatchRegion.fromCalibration(calibration), minThreshold: camera.minChange),
        _tracker = ThrowTracker(calibration),
        _debug = WatchDebugLog(calibration);

  final TargetCamera camera;
  final TargetCalibration calibration;
  final MotionDetector _detector;
  final ThrowTracker _tracker;
  final WatchDebugLog _debug;

  /// Frames closer together than this are skipped: ~15 a second is enough
  /// to see a throw. Quick draw times throws, so it looks at every frame.
  final Duration interval;
  static const beforeRefresh = Duration(seconds: 1);

  final _events = StreamController<ThrowEvent>.broadcast();
  final state = ValueNotifier(WatchState.watching);
  StreamSubscription<CameraFrame>? _frames;
  Duration? _lastProcessed;

  RgbImage? _fullBefore;
  Duration? _fullBeforeAt;
  var _capturing = false;
  (MotionEpisode, ThrowOutcome, int)? _awaitingAfter;

  /// The last finished episode (for status text).
  MotionEpisode? lastEpisode;
  ThrowOutcome? lastOutcome;

  Stream<ThrowEvent> get events => _events.stream;

  void start() => _frames ??= camera.frames().listen(_onFrame);

  var _paused = false;

  /// The last picture analysed, and the one from just before a pause, to
  /// check afterwards whether the phone moved.
  LumaImage? _lastLuma;
  LumaImage? _beforePause;

  /// When watching resumed, once a frame has come (for [moveCheckDelay]).
  Duration? _resumedAt;

  /// How long after resuming the phone-moved check waits: a tripod tapped
  /// lightly wobbles for a moment, then settles where it was.
  static const moveCheckDelay = Duration(milliseconds: 500);

  final _moves = StreamController<double>.broadcast();

  /// After a pause, the shift (pixels at ~320 px) if the phone moved
  /// ([phoneMovedShift] or more): the rings may no longer line up.
  Stream<double> get moves => _moves.stream;

  /// Frames are ignored until [resume] (score corrections: while someone is
  /// at the phone). The knives in the board are still remembered.
  void pause() {
    if (_paused) return;
    _paused = true;
    _beforePause = _lastLuma;
  }

  /// Watches again, starting afresh from the next frame (the motion
  /// reference and the full-resolution before picture are taken again);
  /// then, once the board is still, checks the phone didn't move.
  void resume() {
    if (!_paused) return;
    _paused = false;
    _detector.restart();
    _lastProcessed = null;
    _fullBeforeAt = null;
    _resumedAt = null;
    state.value = WatchState.watching;
  }

  /// The phone-moved check, on a still frame [moveCheckDelay] after resuming.
  void _checkMove(LumaImage luma, Duration time, WatchState state) {
    final before = _beforePause;
    if (before == null) return;
    final resumed = _resumedAt ??= time;
    if (time - resumed < moveCheckDelay || state != WatchState.watching) return;
    _beforePause = null;
    if (before.width != luma.width || before.height != luma.height) return;
    final shift = cameraShift(before, luma, _detector.region);
    if (shift >= phoneMovedShift && !_moves.isClosed) _moves.add(shift);
  }

  /// Stops watching. [state] isn't disposed: a widget may still be listening
  /// until its next rebuild, and it holds no resources.
  Future<void> dispose() async {
    await _frames?.cancel();
    _frames = null;
    await _events.close();
    await _moves.close();
  }

  void _onFrame(CameraFrame frame) {
    if (_paused) return;
    final pending = _awaitingAfter;
    if (pending != null && !_capturing) {
      _awaitingAfter = null;
      _finishStuck(frame, pending.$1, pending.$2, pending.$3);
    }
    final last = _lastProcessed;
    if (last != null && frame.timestamp - last < interval) return;
    _lastProcessed = frame.timestamp;
    final rotation = camera.uprightRotation;
    final luma = frameToLuma(frame, rotation: rotation);
    if (luma == null) return;
    final update = _detector.add(luma, frame.timestamp);
    _debug.onUpdate(update, _detector.threshold);
    state.value = update.state;
    _lastLuma = luma;
    _checkMove(luma, frame.timestamp, update.state);

    final keptAt = _fullBeforeAt;
    if (update.state == WatchState.watching &&
        !_capturing &&
        (keptAt == null || frame.timestamp - keptAt >= beforeRefresh)) {
      _capturing = true;
      _fullBeforeAt = frame.timestamp;
      compute(uprightFullRgb, (frame, rotation)).then((rgb) {
        _capturing = false;
        if (rgb != null) _fullBefore = rgb;
      });
    }

    final episode = update.finished;
    if (episode != null) _onEpisode(episode);
  }

  void _onEpisode(MotionEpisode episode) {
    final (outcome, knifeId) = _tracker.onEpisode(episode);
    _debug.onEpisode(episode, outcome);
    lastEpisode = episode;
    lastOutcome = outcome;
    if (outcome.kind == ThrowOutcomeKind.stuck && isFaceOn(calibration)) {
      final entry = faceOnEntry(outcome.object!, calibration);
      _debug.onEntry(entry);
      _events.add(ThrowEvent(outcome, episode, entry: entry, knifeId: knifeId));
    } else if (outcome.kind == ThrowOutcomeKind.stuck) {
      _awaitingAfter = (episode, outcome, knifeId!); // Entry found from the next frame.
    } else {
      _events.add(ThrowEvent(outcome, episode, knifeId: knifeId));
    }
  }

  Future<void> _finishStuck(CameraFrame frame, MotionEpisode episode, ThrowOutcome outcome, int id) async {
    final before = _fullBefore;
    _capturing = true;
    final after = await compute(uprightFullRgb, (frame, camera.uprightRotation));
    _capturing = false;
    EntryEstimate? entry;
    if (after != null) {
      _fullBefore = after;
      _fullBeforeAt = frame.timestamp;
      if (before != null) entry = await compute(findKnifeEntry, (before, after, calibration));
    }
    _debug.onEntry(entry);
    if (!_events.isClosed) _events.add(ThrowEvent(outcome, episode, entry: entry, knifeId: id));
  }
}

/// For `compute`: a camera frame as an upright, full-resolution RGB image
/// (the same size the calibration was made at).
RgbImage? uprightFullRgb((CameraFrame, int) input) => frameToRgb(input.$1, rotation: input.$2, maxSide: 1920);

/// For `compute`: the new knife's blade entry between two full-resolution
/// pictures.
EntryEstimate? findKnifeEntry((RgbImage, RgbImage, TargetCalibration) input) =>
    GeometricEntryEstimator().estimate(input.$1, input.$2, input.$3);
