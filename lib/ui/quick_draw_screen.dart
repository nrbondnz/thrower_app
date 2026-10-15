import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/recorded_camera.dart';
import '../camera/recording_analysis_feed.dart';
import '../game/quick_draw_judge.dart';
import '../game/quick_draw_targets.dart';
import '../game/quick_draw_watcher.dart';
import '../providers.dart';
import '../vision/ellipse.dart';
import '../vision/target_calibration.dart';
import 'camera_view.dart';
import 'recorded_preview.dart';

/// Quick draw (Live test): two throwers, one board each, both in one view.
/// It plays the clip full screen with its sound (the system bars hidden).
/// Before playing, the user taps the centre of Player 1's board, then
/// Player 2's (there may be more boards in the picture), and locks them.
/// Played locked, "GO" flashes when the footage's countdown says it; every
/// frame is analysed in order (possibly finishing a little after the
/// picture), each board shows its knife's time after go and its score, and
/// the result line says who won ([judgeQuickDraw]).
/// (`docs/thrower/stories/story-checkpoint-quick-draw.md`).
class QuickDrawScreen extends ConsumerStatefulWidget {
  const QuickDrawScreen({super.key});

  @override
  ConsumerState<QuickDrawScreen> createState() => _QuickDrawScreenState();
}

class _QuickDrawScreenState extends ConsumerState<QuickDrawScreen> {
  /// Looking for a board at the last tap.
  var _searching = false;

  /// The last tap found no board.
  var _missed = false;

  /// Every frame of the clip, in order, for the watcher.
  RecordingAnalysisFeed? _feed;

  /// Times and scores the throws while a locked game plays.
  QuickDrawWatcher? _watcher;

  /// Play: with the boards locked, a fresh watcher times and scores each
  /// player's throw from every frame; otherwise the clip just plays.
  void _play(RecordedCamera camera) {
    _stopWatching();
    final targets = ref.read(quickDrawTargetsProvider);
    if (targets.locked) {
      final go = camera.recording.go;
      final feed = RecordingAnalysisFeed(camera, from: go == null ? Duration.zero : go - quickDrawLeadIn);
      setState(() {
        _feed = feed;
        _watcher = QuickDrawWatcher(feed, targets.boards, model: ref.read(targetModelProvider))..start();
      });
    }
    camera.restart();
  }

  void _stopWatching() {
    _watcher?.dispose();
    _feed?.dispose();
    _watcher = null;
    _feed = null;
  }

  /// While a locked game is analysed: the result once both throws are in
  /// (or the whole clip has been analysed), otherwise how far analysis has
  /// got.
  String _progress(RecordedCamera camera, RecordingAnalysisFeed feed, List<QuickDrawThrow?> throws) {
    final done = feed.analysed.value >= camera.pack.frameCount - 1;
    if (throws.every((t) => t != null) || done) return verdictText(judgeQuickDraw(throws, camera.recording.go!));
    final behind = camera.position.value - feed.timeOf(math.max(feed.first, feed.analysed.value));
    if (camera.position.value < feed.timeOf(feed.first)) return 'Watching…';
    if (behind > const Duration(milliseconds: 200)) {
      return 'Analysing… ${(behind.inMilliseconds / 1000).toStringAsFixed(1)} s behind the picture.';
    }
    return 'Watching…';
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _stopWatching();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _findBoardAt(RecordedCamera camera, Point2 tap) async {
    setState(() {
      _searching = true;
      _missed = false;
    });
    final board = boardAt(await ref.read(tapLocatorProvider)(camera, tap));
    if (!mounted) return;
    if (board != null) ref.read(quickDrawTargetsProvider.notifier).add(board);
    setState(() {
      _searching = false;
      _missed = board == null;
    });
  }

  String _instruction(QuickDrawTargets targets) {
    final next = targets.boards.length + 1;
    if (_searching) return "Looking for Player $next's board…";
    if (targets.locked) return 'Boards locked. Press Play.';
    if (targets.complete) return 'Both boards found: lock them, or start again.';
    final again = _missed ? 'No board found there. ' : '';
    return "${again}Tap the centre of Player $next's board.";
  }

  @override
  Widget build(BuildContext context) {
    final camera = ref.watch(quickDrawCameraProvider);
    final targets = ref.watch(quickDrawTargetsProvider);
    final notifier = ref.read(quickDrawTargetsProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: switch (camera) {
              AsyncData(:final value) => RecordedPreview(
                  camera: value,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _BoardsOverlay(
                        targets: targets,
                        imageWidth: value.pack.width,
                        onTap: targets.complete || _searching ? null : (tap) => _findBoardAt(value, tap),
                        playing: value.playing,
                        results: _watcher?.throws,
                        go: value.recording.go,
                      ),
                      if (value.recording.go case final go?) _GoFlash(camera: value, go: go),
                      if (kDebugMode)
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(padding: const EdgeInsets.all(8), child: FrameRateLabel(source: value)),
                        ),
                    ],
                  ),
                ),
              AsyncError(:final error) => Text("The Quick draw clip couldn't load: $error", style: const TextStyle(color: Colors.white)),
              _ => const CircularProgressIndicator(),
            },
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton.filledTonal(
                    key: const Key('quickDrawBack'),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                if (camera case AsyncData(:final value))
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: switch ((_watcher, _feed)) {
                            (final watcher?, final feed?) => ListenableBuilder(
                                listenable: Listenable.merge([watcher.throws, feed.analysed, value.position]),
                                builder: (context, _) => _line(_progress(value, feed, watcher.throws.value)),
                              ),
                            _ => _line(_instruction(targets)),
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (targets.boards.isNotEmpty)
                              OutlinedButton(
                                key: const Key('quickDrawStartAgain'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.black54),
                                onPressed: () {
                                  setState(_stopWatching);
                                  notifier.clear();
                                  // Choose again on the still board, not where playback stopped.
                                  value.rewind();
                                },
                                child: const Text('Start again'),
                              ),
                            if (targets.complete && !targets.locked)
                              FilledButton(
                                key: const Key('quickDrawLock'),
                                onPressed: notifier.lock,
                                child: const Text('Lock boards'),
                              ),
                            _PlayButton(camera: value, onPlay: () => _play(value)),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The instruction or result line at the bottom.
Widget _line(String text) => Text(
      text,
      key: const Key('quickDrawInstruction'),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 16),
    );

/// "GO!" over the picture for a moment when the footage's countdown says go.
class _GoFlash extends StatelessWidget {
  const _GoFlash({required this.camera, required this.go});

  final RecordedCamera camera;
  final Duration go;

  /// How long it shows.
  static const shown = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: camera.position,
      builder: (context, position, _) {
        final on = camera.playing.value && position >= go && position < go + shown;
        return IgnorePointer(
          child: Center(
            child: on
                ? Text(
                    'GO!',
                    key: const Key('quickDrawGo'),
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      shadows: const [Shadow(blurRadius: 12)],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// Each board's rings, with its player number above it (blue while choosing,
/// green once locked), over the picture; and, while choosing (and not
/// playing), taps on the picture in image pixels.
class _BoardsOverlay extends StatelessWidget {
  const _BoardsOverlay({
    required this.targets,
    required this.imageWidth,
    required this.onTap,
    required this.playing,
    required this.results,
    required this.go,
  });

  final QuickDrawTargets targets;
  final int imageWidth;
  final ValueChanged<Point2>? onTap;
  final ValueNotifier<bool> playing;

  /// Each player's throw so far, while a locked game plays.
  final ValueNotifier<List<QuickDrawThrow?>>? results;

  /// When the countdown says go: throws are timed from it.
  final Duration? go;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / imageWidth;
        final throws = results;
        final paint = throws == null
            ? CustomPaint(size: Size.infinite, painter: BoardsPainter(targets, scale: scale))
            : ValueListenableBuilder(
                valueListenable: throws,
                builder: (context, list, _) => CustomPaint(
                  size: Size.infinite,
                  painter: BoardsPainter(targets, scale: scale, results: boardLines(list, go ?? Duration.zero)),
                ),
              );
        final tap = onTap;
        if (tap == null) return paint;
        return ValueListenableBuilder(
          valueListenable: playing,
          builder: (context, isPlaying, child) => isPlaying
              ? child!
              : GestureDetector(
                  key: const Key('quickDrawBoardTap'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => tap(Point2(d.localPosition.dx / scale, d.localPosition.dy / scale)),
                  child: child,
                ),
          child: paint,
        );
      },
    );
  }
}

/// The line under each board: the throw's time after [go] and its score,
/// "bounced" or "false start" ([judgedText]); null until its throw is in.
List<String?> boardLines(List<QuickDrawThrow?> throws, Duration go) {
  final judged = judgeQuickDraw(throws, go).players;
  return [for (final (i, t) in throws.indexed) t == null ? null : judgedText(judged[i])];
}

/// Draws [QuickDrawTargets.boards] at [scale] screen pixels per image pixel,
/// with each player's [results] line under their board.
class BoardsPainter extends CustomPainter {
  BoardsPainter(this.targets, {required this.scale, this.results = const []});

  final QuickDrawTargets targets;
  final double scale;
  final List<String?> results;

  @override
  void paint(Canvas canvas, Size size) {
    final colour = targets.locked ? Colors.greenAccent : Colors.lightBlueAccent;
    final stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final (i, board) in targets.boards.indexed) {
      for (final e in [...board.boundaries.values, board.outer]) {
        canvas.drawPath(_path(e.rescaled(scale)), stroke);
      }
      _label(canvas, board, '${i + 1}', colour);
      if (i < results.length && results[i] != null) _result(canvas, board, results[i]!);
    }
  }

  /// [text] in a dark box just below the board.
  void _result(Canvas canvas, TargetCalibration board, String text) {
    final o = board.outer;
    final bottom = o.cy + math.max(o.semiMajor, o.semiMinor);
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = Offset(o.cx * scale - painter.width / 2, bottom * scale + 8);
    canvas.drawRect((at - const Offset(6, 3)) & Size(painter.width + 12, painter.height + 6), Paint()..color = Colors.black87);
    painter.paint(canvas, at);
  }

  /// The player number in a disc just above the board.
  void _label(Canvas canvas, TargetCalibration board, String text, Color colour) {
    final o = board.outer;
    final top = o.cy - math.max(o.semiMajor, o.semiMinor);
    final at = Offset(o.cx * scale, top * scale - 16);
    canvas.drawCircle(at, 12, Paint()..color = colour);
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  Path _path(Ellipse e) {
    final path = Path();
    for (var i = 0; i <= 120; i++) {
      final p = e.pointAt(2 * math.pi * i / 120);
      i == 0 ? path.moveTo(p.x, p.y) : path.lineTo(p.x, p.y);
    }
    return path;
  }

  @override
  bool shouldRepaint(BoardsPainter old) =>
      old.targets != targets || old.scale != scale || !listEquals(old.results, results);
}

/// Plays the clip from the start; hidden while it plays.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.camera, required this.onPlay});

  final RecordedCamera camera;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: camera.playing,
      builder: (context, playing, _) => playing
          ? const SizedBox.shrink()
          : FilledButton.icon(
              key: const Key('quickDrawPlay'),
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow),
              label: Text(camera.position.value == Duration.zero ? 'Play' : 'Play again'),
            ),
    );
  }
}
