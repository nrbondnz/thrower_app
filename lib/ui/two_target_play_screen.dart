import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/recorded_camera.dart';
import '../camera/target_camera.dart';
import '../game/play_boards_watcher.dart';
import '../game/quick_draw_targets.dart';
import '../game/throw_watcher.dart';
import '../providers.dart';
import '../vision/ellipse.dart';
import '../vision/motion_detector.dart';
import '../vision/target_calibration.dart';
import '../vision/throw_classifier.dart';
import 'camera_view.dart';
import 'play_screen.dart';
import 'quick_draw_boards.dart';
import 'round_marks.dart';

/// Play for two players on two targets, throwing at the same time (Home →
/// Play → 2 players, 2 targets; players-and-targets story, Task 3).
///
/// 1. Tap the centre of Player 1's board, then Player 2's, then **Lock
///    boards** (as in Quick draw; [BoardChoosing]). The camera is at 1×, so
///    both boards are in the picture.
/// 2. Each board is watched on its own crop ([PlayBoardsWatcher]) and scores
///    for its own player only ([Match], [PlayMode.twoTargets]); its marks
///    show on it.
/// 3. The panel says when to collect: "Wait for Player 2" until both rounds
///    are complete, then "Collect your knives / Together, when no one is
///    throwing."; at the end, who won ([PlayersPanel]).
///
/// The boards are kept for the session ([playTargetsProvider]).
class TwoTargetPlayScreen extends ConsumerStatefulWidget {
  const TwoTargetPlayScreen({super.key});

  @override
  ConsumerState<TwoTargetPlayScreen> createState() => _TwoTargetPlayScreenState();
}

class _TwoTargetPlayScreenState extends ConsumerState<TwoTargetPlayScreen> with BoardChoosing {
  PlayBoardsWatcher? _watcher;
  StreamSubscription<BoardThrowEvent>? _events;
  TargetCamera? _camera;
  QuickDrawTargets? _watched;

  /// The camera last set to 1× (once per camera).
  TargetCamera? _unzoomed;

  /// Each board's marks for the round in progress, in player order.
  final _marks = [RoundMarks(), RoundMarks()];
  String? _message;

  @override
  void addBoard(TargetCalibration board) => ref.read(playTargetsProvider.notifier).add(board);

  void _ensureWatcher(TargetCamera camera, QuickDrawTargets targets) {
    if (identical(camera, _camera) && identical(targets, _watched)) return;
    _stopWatcher();
    _camera = camera;
    _watched = targets;
    _watcher = PlayBoardsWatcher(camera, targets.boards)..start();
    _events = _watcher!.events.listen(_onEvent);
    // A Live test recording waits on its first frame until play starts.
    if (camera is RecordedCamera) WidgetsBinding.instance.addPostFrameCallback((_) => camera.restart());
  }

  void _stopWatcher() {
    _events?.cancel();
    _watcher?.dispose();
    _events = null;
    _watcher = null;
    _watched = null;
  }

  void _onEvent(BoardThrowEvent e) {
    final board = e.board, event = e.event;
    final newRound = ref.read(gameProvider).nextThrowStartsRound(board: board);
    ref.read(gameProvider.notifier).onEvent(event, e.calibration, board: board);
    final score = ref.read(gameProvider).players[board].currentRound?.throws.lastOrNull?.score ?? 0;
    setState(() {
      _marks[board].apply(event, score: score, newRound: newRound);
      if (event.outcome.kind != ThrowOutcomeKind.nothing) _message = boardMessage(board, event);
    });
  }

  void _newGame() {
    ref.read(gameProvider.notifier).newGame();
    setState(() {
      for (final m in _marks) {
        m.clear();
      }
      _message = null;
    });
  }

  /// Live test: play the recording again from the start, with a new game.
  void _replay(RecordedCamera camera) {
    _newGame();
    camera.restart();
  }

  /// Choose boards again: stop watching and forget the boards (the game's
  /// scores stay).
  void _chooseAgain() {
    _stopWatcher();
    setState(() {
      for (final m in _marks) {
        m.clear();
      }
    });
    ref.read(playTargetsProvider.notifier).clear();
    if (_camera case final RecordedCamera camera) camera.rewind();
  }

  /// Mid-game, a stray tap shouldn't wipe the scores: ask first.
  Future<void> _confirmReset() async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset this game?'),
        content: const Text('Scores will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reset')),
        ],
      ),
    );
    if (reset == true && mounted) _newGame();
  }

  @override
  void dispose() {
    _stopWatcher();
    if (_camera case final RecordedCamera camera) camera.rewind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targets = ref.watch(playTargetsProvider);
    final match = ref.watch(gameProvider);
    ref.listen(historySaveErrorProvider, (_, message) {
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(key: Key('historySaveFailed'), content: Text("Couldn't save this game to History.")),
        );
      }
    });
    final camera = ref.watch(cameraProvider).value;
    // Both boards need the whole picture: a zoom kept from calibrating one
    // target would cut them off.
    if (camera != null && !identical(camera, _unzoomed)) {
      _unzoomed = camera;
      if (camera.zoom != 1) camera.setZoom(1);
    }
    if (!targets.locked) {
      _stopWatcher();
    } else if (camera != null) {
      _ensureWatcher(camera, targets);
    }
    final watcher = _watcher;
    final buttonStyle = OutlinedButton.styleFrom(foregroundColor: Colors.white);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Play'),
        actions: [
          TextButton(onPressed: match.isEmpty ? null : _confirmReset, child: const Text('Reset game')),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: CameraView(
                overlayBuilder: (context, camera) => Stack(
                  fit: StackFit.expand,
                  children: [
                    BoardsOverlay(
                      targets: targets,
                      onTap: targets.complete || searching ? null : (tap) => findBoardAt(camera, tap),
                    ),
                    if (watcher != null)
                      CustomPaint(
                        size: Size.infinite,
                        painter: BoardMarksPainter(
                          targets.boards,
                          _marks,
                          offsets: [for (final c in watcher.crops) Point2(c.x.toDouble(), c.y.toDouble())],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              color: Colors.black,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!targets.locked) ...[
                    quickDrawLine(choosingInstruction(targets, locked: '')),
                    const SizedBox(height: 12),
                  ] else ...[
                    if (watcher != null)
                      ListenableBuilder(
                        listenable: Listenable.merge(watcher.states),
                        builder: (context, _) => Text(
                          boardsStateText([for (final s in watcher.states) s.value]),
                          key: const Key('boardsState'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    const SizedBox(height: 8),
                    PlayersPanel(match: match, message: _message),
                  ],
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (camera is RecordedCamera && targets.locked)
                        ValueListenableBuilder(
                          valueListenable: camera.playing,
                          builder: (context, playing, _) => OutlinedButton(
                            key: const Key('replayRecording'),
                            style: buttonStyle,
                            onPressed: () => _replay(camera),
                            child: Text(playing ? 'Restart the recording' : 'Recording finished: play again'),
                          ),
                        ),
                      if (targets.boards.isNotEmpty)
                        OutlinedButton(
                          key: const Key('playChooseBoardsAgain'),
                          style: buttonStyle,
                          onPressed: _chooseAgain,
                          child: const Text('Choose boards again'),
                        ),
                      if (targets.complete && !targets.locked)
                        FilledButton(
                          key: const Key('playLockBoards'),
                          onPressed: ref.read(playTargetsProvider.notifier).lock,
                          child: const Text('Lock boards'),
                        ),
                      if (match.isOver) FilledButton(onPressed: _newGame, child: const Text('New game')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What Play says about [board]'s [event]: [eventMessage] with the player,
/// e.g. "Player 2: Bounced off: 0."; null clears the last message.
String? boardMessage(int board, ThrowEvent event) {
  if (event.outcome.kind == ThrowOutcomeKind.sceneChanged) {
    return 'The view changed (lights? camera moved?). Choose the boards again if the rings no longer line up.';
  }
  final message = eventMessage(event);
  return message == null ? null : 'Player ${board + 1}: $message';
}

/// Each board's watch state, short: "Player 1: ready · Player 2: throw seen".
String boardsStateText(List<WatchState> states) => [
      for (final (i, s) in states.indexed)
        'Player ${i + 1}: ${switch (s) {
          WatchState.watching => 'ready',
          WatchState.motion || WatchState.settling => 'throw seen',
          WatchState.blocked => 'someone at the board',
        }}',
    ].join(' · ');

/// Each board's round marks ([paintRoundMarks]) over the picture: the
/// knives' entry points are in each board's crop, so [offsets] (the crops'
/// top-left corners) place them in the picture.
class BoardMarksPainter extends CustomPainter {
  BoardMarksPainter(this.boards, this.marks, {required this.offsets});

  final List<TargetCalibration> boards;
  final List<RoundMarks> marks;
  final List<Point2> offsets;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < boards.length && i < marks.length && i < offsets.length; i++) {
      paintRoundMarks(canvas, marks[i], boards[i], scale: size.width / boards[i].imageWidth, offset: offsets[i]);
    }
  }

  @override
  bool shouldRepaint(BoardMarksPainter old) => true;
}
