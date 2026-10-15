import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/target_camera.dart';
import '../game/quick_draw_judge.dart';
import '../game/quick_draw_targets.dart';
import '../game/quick_draw_watcher.dart';
import '../providers.dart';
import '../vision/ellipse.dart';
import '../vision/target_calibration.dart';

/// Choosing Quick draw's boards, shared by the live and recorded screens:
/// tap the centre of Player 1's board, then Player 2's (each is found and
/// outlined), then lock them.
mixin BoardChoosing<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Looking for a board at the last tap.
  var searching = false;

  /// The last tap found no board.
  var missed = false;

  /// Finds the board at [tap] (a fraction of the picture each way) on
  /// [camera]'s next frame, and adds it as the next player's.
  Future<void> findBoardAt(TargetCamera camera, Point2 tap) async {
    setState(() {
      searching = true;
      missed = false;
    });
    final board = boardAt(await ref.read(tapLocatorProvider)(camera, tap));
    if (!mounted) return;
    if (board != null) ref.read(quickDrawTargetsProvider.notifier).add(board);
    setState(() {
      searching = false;
      missed = board == null;
    });
  }

  /// What to do next while choosing; [locked] once the boards are locked.
  String choosingInstruction(QuickDrawTargets targets, {required String locked}) {
    final next = targets.boards.length + 1;
    if (searching) return "Looking for Player $next's board…";
    if (targets.locked) return locked;
    if (targets.complete) return 'Both boards found: lock them, or start again.';
    final again = missed ? 'No board found there. ' : '';
    return "${again}Tap the centre of Player $next's board.";
  }
}

/// The instruction or result line at the bottom of a Quick draw screen.
Widget quickDrawLine(String text) => Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        text,
        key: const Key('quickDrawInstruction'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );

/// Each board's rings, with its player number above it (blue while choosing,
/// green once locked) and its result line under it, over the picture (sized
/// exactly over it); and, while [onTap] is set and [tapsOff] isn't true,
/// taps on the picture, as fractions of its width and height.
class BoardsOverlay extends StatelessWidget {
  const BoardsOverlay({super.key, required this.targets, this.onTap, this.tapsOff, this.throws, this.go = Duration.zero});

  final QuickDrawTargets targets;
  final ValueChanged<Point2>? onTap;

  /// While true, taps are ignored (e.g. while a recording plays).
  final ValueListenable<bool>? tapsOff;

  /// Each player's throw so far, while a game is played: shown under their
  /// board, timed from [go] ([boardLines]).
  final ValueListenable<List<QuickDrawThrow?>>? throws;
  final Duration go;

  @override
  Widget build(BuildContext context) {
    final played = throws;
    final paint = played == null
        ? CustomPaint(size: Size.infinite, painter: BoardsPainter(targets))
        : ValueListenableBuilder(
            valueListenable: played,
            builder: (context, list, _) =>
                CustomPaint(size: Size.infinite, painter: BoardsPainter(targets, results: boardLines(list, go))),
          );
    final tap = onTap;
    if (tap == null) return paint;
    Widget tappable(Widget child) => LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            key: const Key('quickDrawBoardTap'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => tap(Point2(
              d.localPosition.dx / constraints.maxWidth,
              d.localPosition.dy / constraints.maxHeight,
            )),
            child: child,
          ),
        );
    final off = tapsOff;
    if (off == null) return tappable(paint);
    return ValueListenableBuilder(
      valueListenable: off,
      builder: (context, isOff, child) => isOff ? child! : tappable(child!),
      child: paint,
    );
  }
}

/// The line under each board: the throw's time after [go] and its score,
/// "bounced" or "false start" ([judgedText]); null until its throw is in.
List<String?> boardLines(List<QuickDrawThrow?> throws, Duration go) {
  final judged = judgeQuickDraw(throws, go).players;
  return [for (final (i, t) in throws.indexed) t == null ? null : judgedText(judged[i])];
}

/// Draws [QuickDrawTargets.boards] over the picture, each scaled from its own
/// image size to the size painted, with each player's [results] line under
/// their board.
class BoardsPainter extends CustomPainter {
  BoardsPainter(this.targets, {this.results = const []});

  final QuickDrawTargets targets;
  final List<String?> results;

  @override
  void paint(Canvas canvas, Size size) {
    final colour = targets.locked ? Colors.greenAccent : Colors.lightBlueAccent;
    final stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final (i, board) in targets.boards.indexed) {
      final scale = size.width / board.imageWidth;
      for (final e in [...board.boundaries.values, board.outer]) {
        canvas.drawPath(_path(e.rescaled(scale)), stroke);
      }
      _label(canvas, board, scale, '${i + 1}', colour);
      if (i < results.length && results[i] != null) _result(canvas, board, scale, results[i]!);
    }
  }

  /// [text] in a dark box just below the board.
  void _result(Canvas canvas, TargetCalibration board, double scale, String text) {
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
  void _label(Canvas canvas, TargetCalibration board, double scale, String text, Color colour) {
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
  bool shouldRepaint(BoardsPainter old) => old.targets != targets || !listEquals(old.results, results);
}
