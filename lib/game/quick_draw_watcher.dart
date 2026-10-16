import 'dart:async';

import 'package:flutter/foundation.dart';

import '../camera/queued_camera.dart';
import '../camera/target_camera.dart';
import '../scoring/target_model.dart';
import '../vision/motion_detector.dart';
import '../vision/target_calibration.dart';
import '../vision/target_mapping.dart';
import '../vision/throw_classifier.dart';
import 'board_crop.dart';
import 'throw_watcher.dart';

/// How long before "go" Quick draw starts analysing: a knife any earlier
/// would be an obvious false start without the app (Nigel, 2026-10-15), and
/// it leaves the board's watchers a still second to learn the board from.
const quickDrawLeadIn = Duration(seconds: 1);

/// One player's throw in a Quick draw.
class QuickDrawThrow {
  const QuickDrawThrow({required this.impact, required this.stuck, this.score});

  /// When the knife reached the board: the frame with the largest moving
  /// shape on the target (`MotionEpisode.impact`), on the camera's clock
  /// (every board sees the same frames, so players are timed alike).
  final Duration impact;

  /// Stuck in the board; otherwise it bounced out.
  final bool stuck;

  /// For a stuck knife, its ring score (null if the blade's entry wasn't
  /// found).
  final int? score;

  @override
  String toString() => 'QuickDrawThrow(${impact.inMilliseconds} ms, ${stuck ? 'stuck $score' : 'bounce-out'})';
}

/// Watches each Quick draw board with the single-board throw detection
/// ([ThrowWatcher]) on its own crop of the picture ([cropToBoard]), looking
/// at **every** frame (timing needs it), and keeps each player's first throw
/// (stuck or bounce-out) in [throws], in player order.
class QuickDrawWatcher {
  QuickDrawWatcher(this.camera, this.boards, {required this.model, this.cropRadii = 4, this.queue = false})
      : throws = ValueNotifier(List.filled(boards.length, null));

  final TargetCamera camera;

  /// The locked boards, in player order, in the camera's upright picture.
  final List<TargetCalibration> boards;
  final TargetModel model;

  /// Each crop's side in board radii ([cropToBoard]).
  final double cropRadii;

  /// Keep every frame's board crops in a queue ([QueuedCamera]) and analyse
  /// them in order, falling behind if need be: for the live camera, whose
  /// frames can't be fetched again. (A recording's analysis feed already
  /// hands over every frame in order.)
  final bool queue;

  final ValueNotifier<List<QuickDrawThrow?>> throws;

  /// Each board's watch state (watching, motion, …), in player order.
  List<ValueListenable<WatchState>> get states => [for (final w in _watchers) w.state];

  /// Each board's queue, when [queue] is on (for showing how far behind
  /// analysis is).
  final queues = <QueuedCamera>[];
  final _watchers = <ThrowWatcher>[];
  final _subscriptions = <StreamSubscription<ThrowEvent>>[];

  void start() {
    if (_watchers.isNotEmpty) return;
    for (final (player, board) in boards.indexed) {
      final (camera: crop, :calibration) = cropToBoard(camera, board, cropRadii: cropRadii);
      final watched = queue ? QueuedCamera(crop) : crop;
      if (watched is QueuedCamera) queues.add(watched);
      final watcher = ThrowWatcher(watched, calibration, interval: Duration.zero)..start();
      _watchers.add(watcher);
      _subscriptions.add(watcher.events.listen((event) => _onEvent(player, event, calibration)));
    }
  }

  void _onEvent(int player, ThrowEvent event, TargetCalibration calibration) {
    final kind = event.outcome.kind;
    if (throws.value[player] != null || (kind != ThrowOutcomeKind.stuck && kind != ThrowOutcomeKind.bounceOut)) return;
    final entry = event.entry;
    final stuck = kind == ThrowOutcomeKind.stuck;
    final next = [...throws.value];
    next[player] = QuickDrawThrow(
      impact: event.episode.impact ?? event.episode.start,
      stuck: stuck,
      score: stuck && entry != null ? model.scoreAt(TargetMapping(calibration).toTarget(entry.point)) : null,
    );
    throws.value = next;
  }

  /// Takes no new frames; those already queued are still analysed.
  Future<void> stopFeeding() async {
    for (final q in queues) {
      await q.stopTaking();
    }
  }

  var _disposed = false;

  /// Stops watching. [throws] keeps its last value.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    for (final w in _watchers) {
      await w.dispose();
    }
    for (final q in queues) {
      await q.dispose();
    }
  }
}
