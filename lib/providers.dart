import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_service.dart';
import 'camera/live_camera.dart';
import 'game/throw_watcher.dart';
import 'scoring/game_session.dart';
import 'scoring/target_model.dart';
import 'vision/target_calibration.dart';
import 'vision/target_mapping.dart';
import 'vision/throw_classifier.dart';

/// Wiring for the app's layers. Tests override any of these with fakes.

final targetModelProvider = Provider<TargetModel>((ref) => TargetModel.ikthof());

/// Normalised radii of the ring boundaries inside the target (every ring's
/// outer edge except the outermost), which the ring finder looks for.
final ringBoundaryRadiiProvider = Provider<List<double>>((ref) {
  final rings = ref.watch(targetModelProvider).rings;
  return [for (final r in rings.take(rings.length - 1)) r.outerRadius];
});

/// The open back camera. Released as soon as nothing is watching it (e.g. the
/// camera screen closes or the app goes to the background).
///
/// Never retried automatically: on Android a retry after "Don't allow" would
/// show the permission prompt again. The user retries from the error view.
final liveCameraProvider = FutureProvider.autoDispose<LiveCamera>(
  (ref) async {
    final camera = await LiveCamera.open();
    ref.onDispose(camera.dispose);
    return camera;
  },
  retry: (retryCount, error) => null,
);

/// The target calibration for this session: found, adjusted, then locked.
/// Not auto-disposed, so it survives leaving and returning to the screen.
class CalibrationState {
  const CalibrationState(this.calibration, {this.locked = false});

  final TargetCalibration calibration;
  final bool locked;
}

class CalibrationNotifier extends Notifier<CalibrationState?> {
  @override
  CalibrationState? build() => null;

  /// A new (unlocked) calibration, e.g. from "Find target".
  void start(TargetCalibration calibration) => state = CalibrationState(calibration);

  /// A hand adjustment. Ignored once locked.
  void adjust(TargetCalibration calibration) {
    if (state case CalibrationState(locked: false)) state = CalibrationState(calibration);
  }

  void lock() {
    if (state case final s?) state = CalibrationState(s.calibration, locked: true);
  }

  /// "Re-calibrate": keep the outline but allow changes again.
  void unlock() {
    if (state case final s?) state = CalibrationState(s.calibration);
  }
}

final calibrationProvider = NotifierProvider<CalibrationNotifier, CalibrationState?>(CalibrationNotifier.new);

/// The single-player game for this session, fed by [ThrowEvent]s.
class GameNotifier extends Notifier<GameSession> {
  /// Knife id (from the watcher) → (round, throw) it was recorded as, for
  /// knives still in the board.
  final _knives = <int, (int, int)>{};

  @override
  GameSession build() => const GameSession();

  void newGame() {
    _knives.clear();
    state = const GameSession();
  }

  /// Applies what the watcher saw. [calibration] maps a stuck knife's entry
  /// to the target, scored by [targetModelProvider].
  void onEvent(ThrowEvent event, TargetCalibration calibration) {
    // After the last round, new throws aren't recorded (or remembered as
    // knives, so one falling out can't zero a real throw).
    final kind = event.outcome.kind;
    if (state.isOver && (kind == ThrowOutcomeKind.stuck || kind == ThrowOutcomeKind.bounceOut)) return;
    switch (kind) {
      case ThrowOutcomeKind.stuck:
        final entry = event.entry;
        final point = entry == null ? null : TargetMapping(calibration).toTarget(entry.point);
        final score = point == null ? 0 : ref.read(targetModelProvider).scoreAt(point);
        state = state.stuck(score, point);
        if (event.knifeId case final id?) {
          _knives[id] = (state.rounds.length - 1, state.rounds.last.throws.length - 1);
        }
      case ThrowOutcomeKind.bounceOut:
        state = state.bounceOut();
      case ThrowOutcomeKind.fellOut:
        if (_knives.remove(event.knifeId) case (final round, final index)?) state = state.fellOut(round, index);
      case ThrowOutcomeKind.boardVisit:
        _knives.clear();
        state = state.boardVisited();
      case ThrowOutcomeKind.sceneChanged:
        _knives.clear();
    }
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameSession>(GameNotifier.new);

/// No auth provider is chosen yet, so this must be overridden before use.
final authServiceProvider = Provider<AuthService>(
  (ref) => throw UnimplementedError('Auth provider not chosen yet (backend deferred)'),
);
