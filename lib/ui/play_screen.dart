import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/recorded_camera.dart';
import '../camera/target_camera.dart';
import '../game/throw_watcher.dart';
import '../providers.dart';
import '../scoring/game_session.dart';
import '../scoring/game_type.dart';
import '../scoring/match.dart';
import '../vision/ellipse.dart';
import '../vision/motion_detector.dart';
import '../vision/target_calibration.dart';
import '../vision/throw_classifier.dart';
import 'calibration_screen.dart';
import 'camera_view.dart';
import 'post_score_panel.dart';
import 'round_marks.dart';
import 'score_corrections.dart';

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

class _PlayScreenState extends ConsumerState<PlayScreen> implements CorrectionHost {
  ThrowWatcher? _watcher;
  StreamSubscription<ThrowEvent>? _events;
  StreamSubscription<double>? _moves;
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
    _moves = _watcher!.moves.listen((_) => setState(() => _message = phoneMovedMessage));
    // A Live test recording waits on its first frame until play starts.
    if (camera is RecordedCamera) WidgetsBinding.instance.addPostFrameCallback((_) => camera.restart());
  }

  @override
  void pauseWatching() => _watcher?.pause();

  @override
  void resumeWatching() => _watcher?.resume();

  @override
  void addedByHand(int board, ThrowSlot slot, {required bool newRound}) =>
      setState(() => _marks.addByHand(slot, newRound: newRound));

  /// Live test: play the recording again from the start, with a new game.
  void _replay(RecordedCamera camera) {
    _newGame();
    camera.restart();
  }

  void _onEvent(ThrowEvent event, TargetCalibration calibration) {
    final notifier = ref.read(gameProvider.notifier);
    final before = ref.read(gameProvider);
    final newRound = before.nextThrowStartsRound();
    notifier.onEvent(event, calibration);
    final match = ref.read(gameProvider);
    setState(() {
      _marks.apply(event, slot: identical(match, before) ? null : match.lastThrowAt(0), newRound: newRound);
      _message = eventMessage(event, previous: _message);
    });
  }

  void _newGame() {
    ref.read(gameProvider.notifier).newGame();
    setState(() {
      _marks.clear();
      _message = null;
    });
  }

  Future<void> _finishGame() async {
    if (await confirmFinishGame(context) && mounted) ref.read(gameProvider.notifier).finishGame();
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
    _moves?.cancel();
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
    ref.listen(historySaveErrorProvider, (_, message) {
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(key: Key('historySaveFailed'), content: Text("Couldn't save this game to History.")),
        );
      }
    });
    final camera = ref.watch(cameraProvider).value;

    if (calibration == null || !calibration.locked) {
      _stopWatcher();
      return Scaffold(
        appBar: AppBar(title: Text(playTitle(match))),
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
        title: Text(playTitle(match)),
        actions: [
          if (!match.isOver)
            TextButton(
              key: const Key('finishGame'),
              onPressed: match.isEmpty ? null : _finishGame,
              child: const Text('Finish game'),
            ),
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
                      match: match,
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
                    const SizedBox(height: 8),
                    ScoreCorrections(host: this, player: 0, board: 0),
                  ] else ...[
                    PlayersPanel(match: match, message: _message),
                    const SizedBox(height: 8),
                    for (var p = 0; p < match.players.length; p++)
                      ScoreCorrections(host: this, player: p, board: 0, label: rowLabel(match, p)),
                  ],
                  const RoundDoneButton(),
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
                    const PostScorePanel(),
                    const SizedBox(height: 8),
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

/// Round done (Nigel, 2026-10-23): shown once the round has all its throws,
/// so the next round can start without the camera seeing the knives
/// collected (three bounce-outs leave nothing to collect).
class RoundDoneButton extends ConsumerWidget {
  const RoundDoneButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(gameProvider).canEndRound) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FilledButton(
        key: const Key('roundDone'),
        onPressed: ref.read(gameProvider.notifier).endRound,
        child: const Text('Round done'),
      ),
    );
  }
}

/// Play's title: "Ranked · 3 m" for a ranked game, else "Play".
String playTitle(Match match) => match.type == GameType.ranked ? 'Ranked · $rankedDistance m' : 'Play';

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
      '${gameOverText(game)} Final total: ${game.total}',
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

/// What Play says when the phone moved while someone was changing a score
/// ([ThrowWatcher.moves]).
const phoneMovedMessage = 'The phone may have moved. If the green rings no longer line up with the board, '
    'calibrate again when no one is throwing.';

/// "Game over!", or for a game finished early, "Game over after 4 of 9
/// rounds!".
String gameOverText(GameSession game) => game.rounds.length < game.maxRounds
    ? 'Game over after ${game.rounds.length} of ${game.maxRounds} rounds!'
    : 'Game over!';

/// Finish game asks first: it ends the game for everyone.
Future<bool> confirmFinishGame(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish the game now?'),
        content: const Text('It ends with the rounds played so far and is kept in History.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            key: const Key('finishGameConfirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finish'),
          ),
        ],
      ),
    ) ??
    false;

/// What Play says about a board's [event], under the scores; [previous]
/// stays when the event changes nothing.
String? eventMessage(ThrowEvent event, {String? previous}) => switch (event.outcome.kind) {
      ThrowOutcomeKind.stuck => event.entry == null ? "Stuck, but couldn't see where it went in." : null,
      ThrowOutcomeKind.bounceOut => 'Bounced off: 0.',
      ThrowOutcomeKind.fellOut => 'A knife fell out: it scores 0.',
      ThrowOutcomeKind.boardVisit => null,
      ThrowOutcomeKind.sceneChanged =>
        'The view changed (lights? camera moved?). Re-calibrate if the rings no longer line up.',
      ThrowOutcomeKind.nothing => previous,
    };

/// Two players: whose turn it is, what to do (or who won) in large type, to
/// read from the throwing line, then each player's total and round.
class PlayersPanel extends StatelessWidget {
  const PlayersPanel({super.key, required this.match, this.message});

  final Match match;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final footer = matchFooter(match, message: message);
    final headline = turnText(match);
    final detail = turnDetail(match);
    return Column(
      children: [
        if (headline != null)
          Text(
            headline,
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

  /// The player throwing now (both, on two targets), or the winner.
  bool _highlighted(int player) => match.isOver
      ? match.winner == player
      : match.mode == PlayMode.twoTargets || match.turn == player;
}

/// Two players: the big line, kept short to read from the throwing line; at
/// the end, "Mark wins" or "A draw" (players by [Match.nameOf]: "Player 2"
/// without a name). No one is told to throw while
/// someone may be at a board.
/// - One target: "Player 1's turn"; once a turn has all its throws,
///   "Collect your knives".
/// - Two targets: nothing while both are throwing; "Wait for Player 2" once
///   only Player 1's round is complete; "Collect your knives" once both are.
String? turnText(Match match) {
  if (match.isOver) return match.draw ? 'A draw' : '${match.nameOf(match.winner!)} wins';
  if (match.mode == PlayMode.twoTargets) {
    final waiting = _waitingToCollect(match);
    if (waiting.every((w) => w)) return 'Collect your knives';
    if (waiting.any((w) => w)) return 'Wait for ${match.nameOf(waiting.indexOf(false))}';
    return null;
  }
  if (match.turnComplete) return 'Collect your knives';
  return "${match.nameOf(match.turn)}'s turn";
}

/// Under [turnText]: when to collect, and who's next. One target: "When no
/// one is throwing. Then Player 2's turn."; two targets: "Together, when no
/// one is throwing." or "Then collect your knives together."
String? turnDetail(Match match) {
  if (match.isOver) return null;
  if (match.mode == PlayMode.twoTargets) {
    final waiting = _waitingToCollect(match);
    if (waiting.every((w) => w)) return 'Together, when no one is throwing.';
    if (waiting.any((w) => w)) return 'Then collect your knives together.';
    return null;
  }
  return match.turnComplete ? "When no one is throwing. Then ${match.nameOf(match.nextTurn)}'s turn." : null;
}

/// Two targets: each player's round is complete and their knives are still
/// to be collected (or their game is over).
List<bool> _waitingToCollect(Match match) =>
    [for (final g in match.players) g.roundComplete && !g.awaitingNextRound];

/// "Mark: 23" ("Player 1: 23" without a name), the player's game total;
/// once the match is over, the total the result is judged on
/// ([Match.countedTotals]).
String playerTitle(Match match, int player) =>
    '${match.nameOf(player)}: ${match.isOver ? match.countedTotals[player] : match.players[player].total}';

/// The player's round in progress ([roundText]), or every round's total once
/// the match is over, a round beyond the [Match.countedRounds] marked "not
/// counted".
String playerDetail(Match match, int player) {
  final game = match.players[player];
  if (!match.isOver) return roundText(game);
  final rounds = [
    for (final (i, r) in game.rounds.indexed) i < match.countedRounds ? '${r.total}' : '${r.total} (not counted)',
  ];
  return 'Rounds: ${rounds.join(', ')}';
}

/// Under the players: what just happened ([message]), and at the end, a
/// game finished early and when to collect the knives.
String matchFooter(Match match, {String? message}) => [
      ?message,
      if (match.isOver && match.finishedEarly)
        'Finished early: judged on ${match.countedRounds} of ${match.maxRounds} rounds.',
      if (match.isOver) 'Collect your knives when no one is throwing.',
    ].join('\n');

/// The locked rings (green), a yellow circle with its score at each knife's
/// entry, and the marks beside the board; scores from [match].
class PlayOverlayPainter extends CustomPainter {
  PlayOverlayPainter(this.calibration, {required this.scale, required this.marks, required this.match});

  final TargetCalibration calibration;
  final double scale;
  final RoundMarks marks;
  final Match match;

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
    paintRoundMarks(canvas, marks, calibration, match: match, scale: scale);
  }

  @override
  bool shouldRepaint(PlayOverlayPainter old) => true;
}

/// [marks] for the board [calibration] (image pixels × [scale] = screen):
/// a yellow circle with its score at each knife's entry, and orange marks
/// beside the board; a score changed by hand is light blue. Scores come
/// from [match]. [offset] is added to the knives' entry points first (two
/// targets: they're in the board's crop, the board in the picture).
void paintRoundMarks(Canvas canvas, RoundMarks marks, TargetCalibration calibration,
    {required Match match, required double scale, Point2 offset = const Point2(0, 0)}) {
  const radius = PlayOverlayPainter.radius;
  for (final (point, slot) in marks.knives.values) {
    final t = match.throwAt(slot);
    _paintMark(canvas, Offset((point.x + offset.x) * scale, (point.y + offset.y) * scale), '${t?.score ?? 0}',
        markColour(t, Colors.yellowAccent));
  }
  for (var i = 0; i < marks.beside.length; i++) {
    final t = match.throwAt(marks.beside[i]);
    final p = besidePosition(calibration.outer, i, imageWidth: calibration.imageWidth, radius: radius / scale);
    _paintMark(canvas, Offset(p.x * scale, p.y * scale), '${t?.score ?? 0}', markColour(t, Colors.orangeAccent));
  }
}

/// A mark's colour: [usual], or light blue for a score set by hand.
Color markColour(ThrowRecord? t, Color usual) => (t?.corrected ?? false) ? Colors.lightBlueAccent : usual;

void _paintMark(Canvas canvas, Offset at, String text, Color colour) {
  const radius = PlayOverlayPainter.radius;
  canvas.drawCircle(at, radius, Paint()..color = Colors.black);
  canvas.drawCircle(at, radius - 2, Paint()..color = colour);
  final label = TextPainter(
    text: TextSpan(text: text, style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
    textDirection: TextDirection.ltr,
  )..layout();
  label.paint(canvas, at - Offset(label.width / 2, label.height / 2));
}
