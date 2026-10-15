import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_service.dart';
import 'camera/live_camera.dart';
import 'camera/recorded_camera.dart';
import 'camera/target_camera.dart';
import 'game/quick_draw_targets.dart';
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

/// Which recording the Live test is playing in place of the camera, or null
/// for the phone's own camera.
class RecordingChoiceNotifier extends Notifier<Recording?> {
  @override
  Recording? build() => null;

  void use(Recording? recording) => state = recording;
}

final recordingChoiceProvider = NotifierProvider<RecordingChoiceNotifier, Recording?>(RecordingChoiceNotifier.new);

/// The camera the screens watch the target through: the open back camera, or
/// the chosen Live test recording ([recordingChoiceProvider]). Released as
/// soon as nothing is watching it (e.g. the camera screen closes or the app
/// goes to the background). It reopens at the calibration's zoom, so a
/// target found zoomed in still lines up on the Play screen.
///
/// Never retried automatically: on Android a retry after "Don't allow" would
/// show the permission prompt again. The user retries from the error view.
final cameraProvider = FutureProvider.autoDispose<TargetCamera>(
  (ref) async {
    final recording = ref.watch(recordingChoiceProvider);
    final TargetCamera camera = recording == null ? await LiveCamera.open() : await RecordedCamera.load(recording);
    ref.onDispose(camera.dispose);
    final zoom = ref.read(calibrationProvider)?.zoom ?? 1;
    if (zoom != 1) await camera.setZoom(zoom);
    return camera;
  },
  retry: (retryCount, error) => null,
);

/// Quick draw's camera: for now the Live test clip of both boards
/// ([quickDrawRecording]), separate from the single-target [cameraProvider].
/// Released when Quick draw closes.
final quickDrawCameraProvider = FutureProvider.autoDispose<RecordedCamera>(
  (ref) async {
    final camera = await RecordedCamera.load(quickDrawRecording);
    ref.onDispose(camera.dispose);
    return camera;
  },
  retry: (retryCount, error) => null,
);

/// Quick draw's boards, tapped in player order, then locked. Kept while
/// Quick draw is open; leaving it starts over.
class QuickDrawTargetsNotifier extends Notifier<QuickDrawTargets> {
  @override
  QuickDrawTargets build() => const QuickDrawTargets();

  /// The next player's board. Ignored once both are found.
  void add(TargetCalibration board) {
    if (!state.complete) state = QuickDrawTargets(boards: [...state.boards, board]);
  }

  /// "Start again": forget the boards (and the lock).
  void clear() => state = const QuickDrawTargets();

  void lock() {
    if (state.complete) state = QuickDrawTargets(boards: state.boards, locked: true);
  }
}

final quickDrawTargetsProvider =
    NotifierProvider.autoDispose<QuickDrawTargetsNotifier, QuickDrawTargets>(QuickDrawTargetsNotifier.new);

/// Finds the board at a tap; tests replace it.
final tapLocatorProvider = Provider<TapLocator>(
  (ref) => (camera, tap) => locateAtTap(camera, tap, ref.read(ringBoundaryRadiiProvider)),
);

/// The live Quick draw's camera: the phone's back camera, its own (not
/// [cameraProvider], which Calibrate and Play share with the Live test's
/// recordings). Released when Quick draw closes. Never retried automatically
/// (see [cameraProvider]).
final liveQuickDrawCameraProvider = FutureProvider.autoDispose<TargetCamera>(
  (ref) async {
    final camera = await LiveCamera.open();
    ref.onDispose(camera.dispose);
    return camera;
  },
  retry: (retryCount, error) => null,
);

/// The target calibration for this session: found, adjusted, then locked.
/// Not auto-disposed, so it survives leaving and returning to the screen.
/// It belongs to the camera it was made with, so switching between the live
/// camera and a recording starts over.
class CalibrationState {
  const CalibrationState(this.calibration, {this.locked = false, this.zoom = 1});

  final TargetCalibration calibration;
  final bool locked;

  /// The camera zoom the rings were found at; the camera must be at this
  /// zoom for them to line up ([cameraProvider] restores it).
  final double zoom;
}

class CalibrationNotifier extends Notifier<CalibrationState?> {
  @override
  CalibrationState? build() {
    ref.watch(recordingChoiceProvider);
    return null;
  }

  /// A new (unlocked) calibration, e.g. from "Find target", found with the
  /// camera at [zoom].
  void start(TargetCalibration calibration, {double zoom = 1}) => state = CalibrationState(calibration, zoom: zoom);

  /// A hand adjustment. Ignored once locked.
  void adjust(TargetCalibration calibration) {
    if (state case final s? when !s.locked) state = CalibrationState(calibration, zoom: s.zoom);
  }

  void lock() {
    if (state case final s?) state = CalibrationState(s.calibration, locked: true, zoom: s.zoom);
  }

  /// "Re-calibrate": keep the outline (and zoom) but allow changes again.
  void unlock() {
    if (state case final s?) state = CalibrationState(s.calibration, zoom: s.zoom);
  }
}

final calibrationProvider = NotifierProvider<CalibrationNotifier, CalibrationState?>(CalibrationNotifier.new);

/// The single-player game for this session, fed by [ThrowEvent]s.
class GameNotifier extends Notifier<GameSession> {
  /// Knife id (from the watcher) → (round, throw) it was recorded as, for
  /// knives still in the board.
  final _knives = <int, (int, int)>{};

  /// A new game whenever the camera changes (live camera ↔ a recording).
  @override
  GameSession build() {
    ref.watch(recordingChoiceProvider);
    _knives.clear();
    return const GameSession();
  }

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
      case ThrowOutcomeKind.nothing:
        break;
    }
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameSession>(GameNotifier.new);

/// No auth provider is chosen yet, so this must be overridden before use.
final authServiceProvider = Provider<AuthService>(
  (ref) => throw UnimplementedError('Auth provider not chosen yet (backend deferred)'),
);
