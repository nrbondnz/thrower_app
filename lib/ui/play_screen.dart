import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/recorded_camera.dart';
import '../camera/target_camera.dart';
import '../game/throw_watcher.dart';
import '../providers.dart';
import '../scoring/game_session.dart';
import '../scoring/match.dart';
import '../vision/motion_detector.dart';
import '../vision/target_calibration.dart';
import '../vision/throw_classifier.dart';
import 'calibration_screen.dart';
import 'camera_view.dart';
import 'round_marks.dart';

/// Play on one target: the locked target in the live picture; each throw is
/// detected and scored, with a yellow circle showing its score where each
/// knife went in this round and a "0" beside the board for each bounce-out
/// ([RoundMarks]). Games of 9 rounds of 3; collecting the knives (someone at the
/// board) closes the round. One player, or two taking turns ([PlayMode.sharedTarget]:
/// whose turn it is in large type, both players' totals, the winner).
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  ThrowWatcher? _watcher;
  StreamSubscription<ThrowEvent>? _events;
  TargetCamera? _camera;
  TargetCalibration? _calibration;

  /// This round's marks on the board.
  final _marks = RoundMarks();
  String? _message;

  void _ensureWatcher(TargetCamera camera, TargetCalibration calibration) {
    if (identical(camera, _camera) && identical(calibration, _calibration)) return;
    _stopWatcher();
    _camera = camera;
    _calibration = calibration;
    _watcher = ThrowWatcher(camera, calibration)..start();
    _events = _watcher!.events.listen((event) => _onEvent(event, calibration));
    // A Live test recording waits on its first frame until play starts.
    if (camera is RecordedCamera) WidgetsBinding.instance.addPostFrameCallback((_) => camera.restart());
  }

  /// Live test: play the recording again from the start, with a new game.
  void _replay(RecordedCamera camera) {
    _newGame();
    camera.restart();
  }

  void _onEvent(ThrowEvent event, TargetCalibration calibration) {
    final notifier = ref.read(gameProvider.notifier);
    final newRound = ref.read(gameProvider).nextThrowStartsRound();
    notifier.onEvent(event, calibration);
    final match = ref.read(gameProvider);
    final score = match.players[match.playerAt(0)].currentRound?.throws.lastOrNull?.score ?? 0;
    setState(() {
      _marks.apply(event, score: score, newRound: newRound);
      switch (event.outcome.kind) {
        case ThrowOutcomeKind.stuck:
          _message = event.entry == null ? "Stuck, but couldn't see where it went in." : null;
        case ThrowOutcomeKind.bounceOut:
          _message = 'Bounced off: 0.';
        case ThrowOutcomeKind.fellOut:
          _message = 'A knife fell out: it scores 0.';
        case ThrowOutcomeKind.boardVisit:
          _message = null;
        case ThrowOutcomeKind.sceneChanged:
          _message = 'The view changed (lights? camera moved?). Re-calibrate if the rings no longer line up.';
        case ThrowOutcomeKind.nothing:
          break;
      }
    });
  }

  void _newGame() {
    ref.read(gameProvider.notifier).newGame();
    setState(() {
      _marks.clear();
      _message = null;
    });
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

  void _stopWatcher() {
    _events?.cancel();
    _watcher?.dispose();
    _watcher = null;
  }

  @override
  void dispose() {
    _stopWatcher();
    // A Live test recording plays only while Play is open: back on the
    // calibrate screen it waits on its first frame again.
    if (_camera case final RecordedCamera camera) camera.rewind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calibration = ref.watch(calibrationProvider);
    final match = ref.watch(gameProvider);
    final game = match.players.first;
    final camera = ref.watch(cameraProvider).value;

    if (calibration == null || !calibration.locked) {
      _stopWatcher();
      return Scaffold(
        appBar: AppBar(title: const Text('Play')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Calibrate and lock the target first.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const CalibrationScreen())),
                  child: const Text('Calibrate target'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (camera != null) _ensureWatcher(camera, calibration.calibration);
    final watcher = _watcher;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Play'),
        actions: [
          TextButton(
            onPressed: match.isEmpty ? null : _confirmReset,
            child: const Text('Reset game'),
          ),
        ],
      ),
      // Keep content above the system navigation bar (Android 15 draws apps
      // edge to edge) and the iPhone home indicator; the AppBar handles the top.
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: CameraView(
                overlayBuilder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) => CustomPaint(
                    size: Size.infinite,
                    painter: PlayOverlayPainter(
                      calibration.calibration,
                      scale: constraints.maxWidth / calibration.calibration.imageWidth,
                      marks: _marks,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              color: Colors.black,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (watcher != null)
                    ValueListenableBuilder(
                      valueListenable: watcher.state,
                      builder: (context, state, _) => Text(
                        playStateText(state),
                        key: const Key('playState'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (match.players.length == 1) ...[
                    Text(
                      roundText(game),
                      key: const Key('roundText'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gameText(game, message: _message),
                      key: const Key('gameText'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ] else
                    _PlayersPanel(match: match, message: _message),
                  if (camera is RecordedCamera) ...[
                    const SizedBox(height: 12),
                    ValueListenableBuilder(
                      valueListenable: camera.playing,
                      builder: (context, playing, _) => OutlinedButton(
                        key: const Key('replayRecording'),
                        onPressed: () => _replay(camera),
                        child: Text(playing ? 'Restart the recording' : 'Recording finished: play again'),
                      ),
                    ),
                  ],
                  if (match.isOver) ...[
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _newGame, child: const Text('New game')),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String playStateText(WatchState state) => switch (state) {
      WatchState.watching => 'Ready: throw when it’s your turn.',
      WatchState.motion || WatchState.settling => 'Throw seen: waiting for the board to settle…',
      WatchState.blocked => 'Someone is at the board.',
    };

/// "Round 2 of 9: 4 · 3 · –  (7)".
String roundText(GameSession game) {
  // Once the knives are collected, the next round is shown straight away
  // (backlog #12, 2026-10-15), not after its first throw.
  final round = game.awaitingNextRound ? null : game.currentRound;
  final throws = round?.throws ?? const <ThrowRecord>[];
  final number = game.roundNumber;
  final marks = [
    for (final t in throws) t.unscored ? '?' : '${t.score}',
    for (var i = throws.length; i < game.throwsPerRound; i++) '–',
  ];
  return 'Round $number of ${game.maxRounds}: ${marks.join(' · ')}  (${round?.total ?? 0})';
}

/// The game total, the previous rounds, and what to do next (or the final
/// result once the game is over).
String gameText(GameSession game, {String? message}) {
  if (game.isOver) {
    return [
      'Game over! Final total: ${game.total}',
      'Rounds: ${[for (final r in game.rounds) r.total].join(', ')}',
      'Collect your knives when no one is throwing.',
    ].join('\n');
  }
  final lines = <String>[
    ?message,
    if (game.roundComplete && !game.awaitingNextRound)
      'Round complete: ${game.currentRound!.total}. Collect your knives when no one is throwing.',
    'Game total: ${game.total}',
    if (game.finishedRounds.isNotEmpty) 'Rounds: ${[for (final r in game.finishedRounds) r.total].join(', ')}',
  ];
  return lines.join('\n');
}

/// Two players: whose turn it is (or who won) in large type, to read from
/// the throwing line, then each player's total and round.
class _PlayersPanel extends StatelessWidget {
  const _PlayersPanel({required this.match, this.message});

  final Match match;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final footer = matchFooter(match, message: message);
    final detail = turnDetail(match);
    return Column(
      children: [
        Text(
          turnText(match),
          key: const Key('turnText'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: match.isOver ? Colors.greenAccent : Colors.yellowAccent,
            fontSize: match.isOver ? 44 : 32,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (detail != null)
          Text(detail, key: const Key('turnDetail'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.yellowAccent, fontSize: 18)),
        const SizedBox(height: 8),
        for (var i = 0; i < match.players.length; i++) ...[
          Text(
            playerTitle(match, i),
            key: Key('playerTitle$i'),
            style: TextStyle(
              color: _highlighted(i) ? Colors.white : Colors.white60,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            playerDetail(match, i),
            key: Key('playerDetail$i'),
            textAlign: TextAlign.center,
            style: TextStyle(color: _highlighted(i) ? Colors.white : Colors.white60),
          ),
          const SizedBox(height: 4),
        ],
        if (footer.isNotEmpty)
          Text(footer, key: const Key('matchFooter'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  /// The player throwing now, or the winner.
  bool _highlighted(int player) => match.isOver ? match.winner == player : match.turn == player;
}

/// Two players: the big line, kept short to read from the throwing line.
/// "Player 1's turn"; once a turn has all its throws, "Collect your knives"
/// (no one is told to throw while someone may be at the board); at the end,
/// "Player 2 wins" or "A draw".
String turnText(Match match) {
  if (match.isOver) {
    final winner = match.winner;
    return winner == null ? 'A draw' : 'Player ${winner + 1} wins';
  }
  if (match.turnComplete) return 'Collect your knives';
  return "Player ${match.turn + 1}'s turn";
}

/// Under [turnText] when the knives are to be collected: "When no one is
/// throwing. Then Player 2's turn."; otherwise nothing.
String? turnDetail(Match match) =>
    !match.isOver && match.turnComplete ? "When no one is throwing. Then Player ${match.nextTurn + 1}'s turn." : null;

/// "Player 1: 23", the player's game total.
String playerTitle(Match match, int player) => 'Player ${player + 1}: ${match.players[player].total}';

/// The player's round in progress ([roundText]), or every round's total once
/// the match is over.
String playerDetail(Match match, int player) {
  final game = match.players[player];
  if (match.isOver) return 'Rounds: ${[for (final r in game.rounds) r.total].join(', ')}';
  return roundText(game);
}

/// Under the players: what just happened ([message]), and at the end, when
/// to collect the knives.
String matchFooter(Match match, {String? message}) => [
      ?message,
      if (match.isOver) 'Collect your knives when no one is throwing.',
    ].join('\n');

/// The locked rings (green), a yellow circle with its score at each knife's
/// entry, and the "0" marks beside the board.
class PlayOverlayPainter extends CustomPainter {
  PlayOverlayPainter(this.calibration, {required this.scale, required this.marks});

  final TargetCalibration calibration;
  final double scale;
  final RoundMarks marks;

  /// Mark radius in screen pixels.
  static const radius = 11.0;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final e in [...calibration.boundaries.values, calibration.outer]) {
      final path = Path();
      for (var i = 0; i <= 120; i++) {
        final p = e.pointAt(2 * math.pi * i / 120);
        i == 0 ? path.moveTo(p.x * scale, p.y * scale) : path.lineTo(p.x * scale, p.y * scale);
      }
      canvas.drawPath(path, ring);
    }
    for (final (point, score) in marks.knives.values) {
      _mark(canvas, Offset(point.x * scale, point.y * scale), '$score', Colors.yellowAccent);
    }
    for (var i = 0; i < marks.beside.length; i++) {
      final p = besidePosition(calibration.outer, i, imageWidth: calibration.imageWidth, radius: radius / scale);
      _mark(canvas, Offset(p.x * scale, p.y * scale), marks.beside[i], Colors.orangeAccent);
    }
  }

  void _mark(Canvas canvas, Offset at, String text, Color colour) {
    canvas.drawCircle(at, radius, Paint()..color = Colors.black);
    canvas.drawCircle(at, radius - 2, Paint()..color = colour);
    final label = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, at - Offset(label.width / 2, label.height / 2));
  }

  @override
  bool shouldRepaint(PlayOverlayPainter old) => true;
}
