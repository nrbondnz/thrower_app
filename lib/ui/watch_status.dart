import 'dart:async';

import 'package:flutter/material.dart';

import '../camera/live_camera.dart';
import '../game/throw_watcher.dart';
import '../vision/entry_point.dart';
import '../vision/motion_detector.dart';
import '../vision/target_calibration.dart';
import '../vision/throw_classifier.dart';

/// While the target is locked on the calibration screen: watches the board
/// ([ThrowWatcher]) and shows what it sees, as a check of throw detection.
class WatchStatus extends StatefulWidget {
  const WatchStatus({super.key, required this.camera, required this.calibration, this.onKnifeEntry});

  final LiveCamera camera;
  final TargetCalibration calibration;

  /// Called when a stuck knife's blade entry has been found (image pixel in
  /// the calibration's upright frame), or with null if it couldn't be.
  final ValueChanged<EntryEstimate?>? onKnifeEntry;

  @override
  State<WatchStatus> createState() => _WatchStatusState();
}

class _WatchStatusState extends State<WatchStatus> {
  late ThrowWatcher _watcher;
  StreamSubscription<ThrowEvent>? _events;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(WatchStatus old) {
    super.didUpdateWidget(old);
    if (old.calibration != widget.calibration || old.camera != widget.camera) {
      _stop();
      _start();
    }
  }

  void _start() {
    _watcher = ThrowWatcher(widget.camera, widget.calibration)..start();
    _events = _watcher.events.listen((event) {
      if (event.outcome.kind == ThrowOutcomeKind.stuck) widget.onKnifeEntry?.call(event.entry);
      if (mounted) setState(() {});
    });
  }

  void _stop() {
    _events?.cancel();
    _watcher.dispose();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _watcher.state,
      builder: (context, state, _) => Text(
        watchStatusText(state, _watcher.lastEpisode, outcome: _watcher.lastOutcome),
        key: const Key('watchStatus'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}

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
    ThrowOutcomeKind.fellOut => 'A knife fell out (0)',
    null => null,
  };
  final seconds = (last.settled - last.start).inMilliseconds / 1000;
  return '$now\n${what == null ? '' : '$what. '}Last: ${seconds.toStringAsFixed(1)} s of motion, '
      'peak ${(last.peakChange * 100).toStringAsFixed(1)}%, '
      '${(last.changeFromBefore * 100).toStringAsFixed(1)}% changed from before'
      '${last.acceptedNewScene ? ' (accepted as the new view)' : ''}';
}
