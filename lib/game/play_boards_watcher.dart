import 'dart:async';

import 'package:flutter/foundation.dart';

import '../camera/cropped_camera.dart';
import '../camera/target_camera.dart';
import '../vision/motion_detector.dart';
import '../vision/target_calibration.dart';
import 'board_crop.dart';
import 'throw_watcher.dart';

/// A [ThrowEvent] from one of the boards: [calibration] is that board's, in
/// its own crop (which the event's entry point is in).
class BoardThrowEvent {
  const BoardThrowEvent(this.board, this.event, this.calibration);

  /// The board's index, in player order (0 for Player 1).
  final int board;
  final ThrowEvent event;
  final TargetCalibration calibration;
}

/// Two-target Play: watches each board with the single-board throw detection
/// ([ThrowWatcher], at its usual pace) on its own crop of the picture
/// ([cropToBoard]), and reports every event with the board it came from.
/// Unlike Quick draw, which keeps only each player's first throw, this keeps
/// watching for a whole game: throws, knives falling out, collections.
class PlayBoardsWatcher {
  PlayBoardsWatcher(this.camera, this.boards, {this.cropRadii = 4});

  final TargetCamera camera;

  /// The locked boards, in player order, in the camera's upright picture.
  final List<TargetCalibration> boards;
  final double cropRadii;

  /// Each board's crop of the picture (for placing its marks).
  final crops = <CroppedCamera>[];
  final _watchers = <ThrowWatcher>[];
  final _subscriptions = <StreamSubscription<ThrowEvent>>[];
  final _moveSubscriptions = <StreamSubscription<double>>[];
  final _events = StreamController<BoardThrowEvent>.broadcast();
  final _moves = StreamController<int>.broadcast();

  Stream<BoardThrowEvent> get events => _events.stream;

  /// After a pause, each board whose picture moved ([ThrowWatcher.moves]).
  Stream<int> get moves => _moves.stream;

  /// Each board's watch state (watching, motion, …), in player order.
  List<ValueListenable<WatchState>> get states => [for (final w in _watchers) w.state];

  void start() {
    if (_watchers.isNotEmpty) return;
    for (final (board, b) in boards.indexed) {
      final (camera: crop, :calibration) = cropToBoard(camera, b, cropRadii: cropRadii);
      crops.add(crop);
      final watcher = ThrowWatcher(crop, calibration)..start();
      _watchers.add(watcher);
      _subscriptions.add(watcher.events.listen((event) {
        if (!_events.isClosed) _events.add(BoardThrowEvent(board, event, calibration));
      }));
      _moveSubscriptions.add(watcher.moves.listen((_) {
        if (!_moves.isClosed) _moves.add(board);
      }));
    }
  }

  /// Pauses every board's watcher ([ThrowWatcher.pause]).
  void pause() {
    for (final w in _watchers) {
      w.pause();
    }
  }

  /// Resumes every board's watcher ([ThrowWatcher.resume]).
  void resume() {
    for (final w in _watchers) {
      w.resume();
    }
  }

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    for (final s in _moveSubscriptions) {
      await s.cancel();
    }
    for (final w in _watchers) {
      await w.dispose();
    }
    await _events.close();
    await _moves.close();
  }
}
