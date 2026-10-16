import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'auth/auth_service.dart';
import 'camera/live_camera.dart';
import 'camera/recorded_camera.dart';
import 'camera/target_camera.dart';
import 'game/quick_draw_targets.dart';
import 'game/start_signal.dart';
import 'game/throw_watcher.dart';
import 'history/game_history.dart';
import 'history/game_record.dart';
import 'scoring/game_session.dart';
import 'scoring/match.dart';
import 'scoring/target_model.dart';
import 'sound/signal_sounds.dart';
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

  /// "Choose boards again": forget the boards (and the lock).
  void clear() => state = const QuickDrawTargets();

  void lock() {
    if (state.complete) state = QuickDrawTargets(boards: state.boards, locked: true);
  }
}

final quickDrawTargetsProvider =
    NotifierProvider.autoDispose<QuickDrawTargetsNotifier, QuickDrawTargets>(QuickDrawTargetsNotifier.new);

/// Two-target Play's boards, tapped Player 1 then Player 2 and locked, as in
/// Quick draw but kept for the session (like [calibrationProvider]), so
/// leaving Play and coming back keeps them. They belong to the camera they
/// were found with, so switching between the live camera and a recording
/// starts over.
class PlayTargetsNotifier extends QuickDrawTargetsNotifier {
  @override
  QuickDrawTargets build() {
    ref.watch(recordingChoiceProvider);
    return const QuickDrawTargets();
  }
}

final playTargetsProvider = NotifierProvider<PlayTargetsNotifier, QuickDrawTargets>(PlayTargetsNotifier.new);

/// Finds the board at a tap; tests replace it.
final tapLocatorProvider = Provider<TapLocator>(
  (ref) => (camera, tap) => locateAtTap(camera, tap, ref.read(ringBoundaryRadiiProvider)),
);

/// The live Quick draw's camera: the phone's back camera, its own (not
/// [cameraProvider], which Calibrate and Play share with the Live test's
/// recordings), asking for **60 fps**. Released when Quick draw closes.
/// Never retried automatically (see [cameraProvider]).
final liveQuickDrawCameraProvider = FutureProvider.autoDispose<TargetCamera>(
  (ref) async {
    final camera = await LiveCamera.open(fps: 60);
    ref.onDispose(camera.dispose);
    return camera;
  },
  retry: (retryCount, error) => null,
);

/// Quick draw's start-signal beeps and result chime; released with Quick draw.
final signalSoundsProvider = Provider.autoDispose<SignalSounds>((ref) {
  final sounds = AssetSignalSounds();
  ref.onDispose(sounds.dispose);
  return sounds;
});

/// A new start signal's timing, with a random pause; tests fix it.
final startScheduleProvider = Provider<StartSchedule Function()>((ref) {
  final random = math.Random();
  return () => StartSchedule.random(random);
});

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

/// How Play is played (the setup screen after Home → Play): one player, two
/// on one target, or two on two targets. Kept for the session, so the setup
/// screen offers the last choice again.
class PlayModeNotifier extends Notifier<PlayMode> {
  @override
  PlayMode build() => PlayMode.solo;

  void choose(PlayMode mode) => state = mode;
}

final playModeProvider = NotifierProvider<PlayModeNotifier, PlayMode>(PlayModeNotifier.new);

/// How many rounds a game of Play has (the setup screen; Nigel, 2026-10-16):
/// one of [choices], 9 unless chosen. Kept for the session, like
/// [playModeProvider].
class GameLengthNotifier extends Notifier<int> {
  static const choices = [3, 5, 9];

  @override
  int build() => const GameSession().maxRounds;

  void choose(int rounds) => state = rounds;
}

final gameLengthProvider = NotifierProvider<GameLengthNotifier, int>(GameLengthNotifier.new);

/// The time now, for when a game finished; tests fix it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Why the last finished game couldn't be kept in the history, or null.
/// Play shows it; it's cleared by the next save that works.
class HistorySaveErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? message) => state = message;
}

final historySaveErrorProvider = NotifierProvider<HistorySaveErrorNotifier, String?>(HistorySaveErrorNotifier.new);

/// This session's game of Play, for one or two players ([Match]), fed by
/// each board's [ThrowEvent]s. A game is kept in the history
/// ([gameHistoryProvider]) when it finishes: once, under the time it
/// finished, saved again under that time if a knife falling out afterwards
/// changes a score.
class GameNotifier extends Notifier<Match> {
  /// (board, knife id from that board's watcher) → (player, round, throw) it
  /// was recorded as, for knives still in a board.
  final _knives = <(int, int), (int, int, int)>{};

  /// When this game finished (null while it's on).
  DateTime? _finishedAt;

  /// The rounds last kept for this game, so an unchanged game isn't saved
  /// again (e.g. its knives being collected after the end).
  String? _kept;

  /// A new game whenever the camera (live camera ↔ a recording), the play
  /// mode or the game length changes.
  @override
  Match build() {
    ref.watch(recordingChoiceProvider);
    final mode = ref.watch(playModeProvider);
    final rounds = ref.watch(gameLengthProvider);
    _knives.clear();
    _finishedAt = null;
    _kept = null;
    return Match(mode, rules: GameSession(maxRounds: rounds));
  }

  /// The same mode and length, from the start.
  void newGame() {
    _knives.clear();
    _finishedAt = null;
    _kept = null;
    state = Match(state.mode, rules: GameSession(maxRounds: state.maxRounds));
  }

  /// Score corrections (Nigel, 2026-10-17): [player]'s throw [throwIndex]
  /// of round [roundIndex] now scores [score]. A game that's over is kept
  /// again with the new score.
  void setScore(int player, int roundIndex, int throwIndex, int score) =>
      _change(state.setScore(player, roundIndex, throwIndex, score));

  /// A throw the camera didn't see (0: a miss), as the next throw at
  /// [board]; it can end the game as a detected throw would.
  void addThrow(int score, {int board = 0}) {
    if (!state.takesThrowAt(board)) return;
    _change(state.byHand(score, board: board));
  }

  /// A throw added to [player]'s earlier round [roundIndex], one collected
  /// early.
  void addToRound(int player, int roundIndex, int score) => _change(state.addToRound(player, roundIndex, score));

  void _change(Match next) {
    if (identical(next, state)) return;
    state = next;
    if (state.isOver) _keep();
  }

  /// Finish game: ends the match now, with the rounds played so far, and
  /// keeps it in the history. Nothing happens to a game that's over or has
  /// no throws.
  void finishGame() {
    if (state.isOver || state.isEmpty) return;
    state = state.finish();
    _keep();
  }

  /// Applies what [board]'s watcher saw (board 0 on one target).
  /// [calibration] maps a stuck knife's entry to the target, scored by
  /// [targetModelProvider].
  void onEvent(ThrowEvent event, TargetCalibration calibration, {int board = 0}) {
    // After the last round, new throws aren't recorded (or remembered as
    // knives, so one falling out can't zero a real throw).
    final kind = event.outcome.kind;
    if (!state.takesThrowAt(board) && (kind == ThrowOutcomeKind.stuck || kind == ThrowOutcomeKind.bounceOut)) return;
    final before = state;
    _apply(kind, event, calibration, board);
    if (state.isOver && !identical(state, before)) _keep();
  }

  void _apply(ThrowOutcomeKind kind, ThrowEvent event, TargetCalibration calibration, int board) {
    switch (kind) {
      case ThrowOutcomeKind.stuck:
        final entry = event.entry;
        final point = entry == null ? null : TargetMapping(calibration).toTarget(entry.point);
        final score = point == null ? 0 : ref.read(targetModelProvider).scoreAt(point);
        state = state.stuck(score, point, board: board);
        if (event.knifeId case final id?) {
          final player = state.playerAt(board);
          final rounds = state.players[player].rounds;
          _knives[(board, id)] = (player, rounds.length - 1, rounds.last.throws.length - 1);
        }
      case ThrowOutcomeKind.bounceOut:
        state = state.bounceOut(board: board);
      case ThrowOutcomeKind.fellOut:
        if (_knives.remove((board, event.knifeId)) case (final player, final round, final index)?) {
          state = state.fellOut(player, round, index);
        }
      case ThrowOutcomeKind.boardVisit:
        _forgetKnives(board);
        state = state.boardVisited(board: board);
      case ThrowOutcomeKind.sceneChanged:
        _forgetKnives(board);
      case ThrowOutcomeKind.nothing:
        break;
    }
  }

  void _forgetKnives(int board) => _knives.removeWhere((key, _) => key.$1 == board);

  /// Keeps the finished game in the history, with the Live test recording's
  /// name if it was played on one. A failure doesn't stop play: Play says
  /// so ([historySaveErrorProvider]).
  void _keep() {
    final at = _finishedAt ??= ref.read(clockProvider)();
    final record = GameRecord.fromMatch(state, at: at, recording: ref.read(recordingChoiceProvider)?.name);
    final rounds = '${record.players}';
    if (rounds == _kept) return;
    _kept = rounds;
    final errors = ref.read(historySaveErrorProvider.notifier);
    ref.read(gameHistoryProvider).add(record).then(
          (_) => errors.set(null),
          onError: (Object e) => errors.set(e is GameHistoryException ? e.message : '$e'),
        );
  }
}

final gameProvider = NotifierProvider<GameNotifier, Match>(GameNotifier.new);

/// The finished games kept on the phone: a file in the app's own support
/// folder. Tests override it with a temporary folder or a fake.
final gameHistoryProvider = Provider<GameHistory>((ref) => FileGameHistory(getApplicationSupportDirectory));

/// No auth provider is chosen yet, so this must be overridden before use.
final authServiceProvider = Provider<AuthService>(
  (ref) => throw UnimplementedError('Auth provider not chosen yet (backend deferred)'),
);
