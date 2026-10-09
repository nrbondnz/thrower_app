import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/live_camera.dart';
import '../game/throw_watcher.dart';
import '../providers.dart';
import '../scoring/game_session.dart';
import '../vision/ellipse.dart';
import '../vision/motion_detector.dart';
import '../vision/target_calibration.dart';
import '../vision/throw_classifier.dart';
import 'calibration_screen.dart';
import 'camera_screen.dart';

/// Single-player play: the locked target in the live picture; each throw is
/// detected and scored, with a numbered dot where each knife went in this
/// round. Games of 9 rounds of 3; collecting the knives (someone at the
/// board) closes the round.
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  ThrowWatcher? _watcher;
  StreamSubscription<ThrowEvent>? _events;
  LiveCamera? _camera;
  TargetCalibration? _calibration;

  /// Entry points (image pixels) of this round's stuck knives, by knife id.
  final _dots = <int, Point2>{};
  String? _message;

  void _ensureWatcher(LiveCamera camera, TargetCalibration calibration) {
    if (identical(camera, _camera) && identical(calibration, _calibration)) return;
    _stopWatcher();
    _camera = camera;
    _calibration = calibration;
    _watcher = ThrowWatcher(camera, calibration)..start();
    _events = _watcher!.events.listen((event) => _onEvent(event, calibration));
  }

  void _onEvent(ThrowEvent event, TargetCalibration calibration) {
    final notifier = ref.read(gameProvider.notifier);
    final wasComplete = ref.read(gameProvider).roundComplete;
    notifier.onEvent(event, calibration);
    setState(() {
      switch (event.outcome.kind) {
        case ThrowOutcomeKind.stuck:
          if (wasComplete) _dots.clear(); // A new round has started.
          if (event.entry case final entry?) _dots[event.knifeId!] = entry.point;
          _message = event.entry == null ? "Stuck, but couldn't see where it went in." : null;
        case ThrowOutcomeKind.bounceOut:
          if (wasComplete) _dots.clear();
          _message = 'Bounced off: 0.';
        case ThrowOutcomeKind.fellOut:
          _dots.remove(event.knifeId);
          _message = 'A knife fell out: it scores 0.';
        case ThrowOutcomeKind.boardVisit:
          _dots.clear();
          _message = null;
        case ThrowOutcomeKind.sceneChanged:
          _message = 'The view changed (lights? camera moved?). Re-calibrate if the rings no longer line up.';
      }
    });
  }

  void _newGame() {
    ref.read(gameProvider.notifier).newGame();
    setState(() {
      _dots.clear();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calibration = ref.watch(calibrationProvider);
    final game = ref.watch(gameProvider);
    final camera = ref.watch(liveCameraProvider).value;

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
            onPressed: game.rounds.isEmpty ? null : _confirmReset,
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
                      dots: _dots.values.toList(),
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
                  if (game.isOver) ...[
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
  final round = game.currentRound;
  final throws = round?.throws ?? const <ThrowRecord>[];
  final number = game.rounds.isEmpty ? 1 : game.rounds.length;
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
    if (game.roundComplete)
      'Round complete: ${game.currentRound!.total}. Collect your knives when no one is throwing.',
    'Game total: ${game.total}',
    if (game.rounds.length > 1)
      'Rounds: ${[for (final r in game.rounds.take(game.rounds.length - 1)) r.total].join(', ')}',
  ];
  return lines.join('\n');
}

/// The locked rings (green) and a numbered dot at each knife's entry.
class PlayOverlayPainter extends CustomPainter {
  PlayOverlayPainter(this.calibration, {required this.scale, required this.dots});

  final TargetCalibration calibration;
  final double scale;
  final List<Point2> dots;

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
    for (var i = 0; i < dots.length; i++) {
      final at = Offset(dots[i].x * scale, dots[i].y * scale);
      canvas.drawCircle(at, 11, Paint()..color = Colors.black);
      canvas.drawCircle(at, 9, Paint()..color = Colors.yellowAccent);
      final label = TextPainter(
        text: TextSpan(text: '${i + 1}', style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, at - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(PlayOverlayPainter old) => true;
}
