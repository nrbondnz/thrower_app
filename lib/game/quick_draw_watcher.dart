import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../camera/cropped_camera.dart';
import '../camera/target_camera.dart';
import '../scoring/target_model.dart';
import '../vision/target_calibration.dart';
import '../vision/target_mapping.dart';
import '../vision/throw_classifier.dart';
import 'throw_watcher.dart';

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
/// ([ThrowWatcher]) on its own crop of the picture ([CroppedCamera]), looking
/// at **every** frame (timing needs it), and keeps each player's first throw
/// (stuck or bounce-out) in [throws], in player order.
class QuickDrawWatcher {
  QuickDrawWatcher(this.camera, this.boards, {required this.model, this.cropRadii = 4})
      : throws = ValueNotifier(List.filled(boards.length, null));

  final TargetCamera camera;

  /// The locked boards, in player order, in the camera's upright picture.
  final List<TargetCalibration> boards;
  final TargetModel model;

  /// Each crop's side in board radii: the watched region is 3 radii wide
  /// (`WatchRegion.fromCalibration`), so this leaves room around it.
  final double cropRadii;

  final ValueNotifier<List<QuickDrawThrow?>> throws;
  final _watchers = <ThrowWatcher>[];
  final _subscriptions = <StreamSubscription<ThrowEvent>>[];

  void start() {
    if (_watchers.isNotEmpty) return;
    for (final (player, board) in boards.indexed) {
      final o = board.outer;
      final side = math.min((cropRadii * (o.semiMajor + o.semiMinor) / 2).round(), math.min(board.imageWidth, board.imageHeight));
      final x = math.max(0, math.min((o.cx - side / 2).round(), board.imageWidth - side));
      final y = math.max(0, math.min((o.cy - side / 2).round(), board.imageHeight - side));
      final crop = CroppedCamera(camera, x: x, y: y, width: side, height: side);
      final calibration = board.within(crop.x, crop.y, side, side);
      final watcher = ThrowWatcher(crop, calibration, interval: Duration.zero)..start();
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

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    for (final w in _watchers) {
      await w.dispose();
    }
  }
}
