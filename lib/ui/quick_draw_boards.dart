import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/target_camera.dart';
import '../game/area_board.dart';
import '../game/quick_draw_judge.dart';
import '../game/quick_draw_targets.dart';
import '../game/quick_draw_watcher.dart';
import '../providers.dart';
import '../scoring/match.dart';
import '../vision/ellipse.dart';
import '../vision/target_calibration.dart';
import 'calibration_editor.dart';

/// Choosing two boards, shared by the Quick draw screens and two-target
/// Play: tap the centre of Player 1's board, then Player 2's (each is found
/// and outlined), then lock them. Quick draw can instead draw a finger round
/// each board ([boardsDrawnProvider]; [addDrawnBoard]): timed, not scored.
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
    if (board != null) addBoard(board);
    setState(() {
      searching = false;
      missed = board == null;
    });
  }

  /// The loop drawn round a board ([loop]: fractions of the picture each
  /// way), as the next player's board, in the size of [camera]'s picture
  /// ([areaBoard]). A loop too small or too flat for a board is missed.
  Future<void> addDrawnBoard(TargetCamera camera, List<Point2> loop) async {
    setState(() {
      searching = true;
      missed = false;
    });
    final (w, h) = await ref.read(pictureSizerProvider)(camera);
    if (!mounted) return;
    final board = areaBoard([for (final p in loop) Point2(p.x * w, p.y * h)], imageWidth: w, imageHeight: h);
    if (board != null) ref.read(quickDrawTargetsProvider.notifier).add(board, area: true);
    setState(() {
      searching = false;
      missed = board == null;
    });
  }

  /// Keeps a found board as the next player's: Quick draw's by default;
  /// two-target Play keeps its own ([playTargetsProvider]).
  void addBoard(TargetCalibration board) => ref.read(quickDrawTargetsProvider.notifier).add(board);

  /// **Draw round the boards** / **Tap the boards**: switches how Quick
  /// draw's boards are chosen (shown before the first is chosen). Call while
  /// building.
  Widget boardsModeButton() {
    final drawn = ref.watch(boardsDrawnProvider);
    return OutlinedButton(
      key: const Key('quickDrawBoardsMode'),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.black54),
      onPressed: () {
        ref.read(boardsDrawnProvider.notifier).choose(!drawn);
        setState(() => missed = false);
      },
      child: Text(drawn ? 'Tap the boards' : 'Draw round the boards'),
    );
  }

  /// The players, by name ([playerNamesProvider]; "Player N" without one).
  /// Call while building: the screen follows the names.
  List<String> get playerNames {
    final names = ref.watch(playerNamesProvider);
    return [for (var i = 0; i < PlayerNamesNotifier.seats; i++) names[i] ?? playerNumber(i)];
  }

  /// What to do next while choosing; [locked] once the boards are locked.
  /// Call while building.
  /// [drawn]: the boards are drawn round by finger ([boardsDrawnProvider]).
  String choosingInstruction(QuickDrawTargets targets, {required String locked, bool drawn = false}) {
    final next = playerNames[math.min(targets.boards.length, PlayerNamesNotifier.seats - 1)];
    if (searching) return drawn ? "Marking $next's board…" : "Looking for $next's board…";
    if (targets.locked) return locked;
    if (targets.complete) {
      final fit = targets.areas.isEmpty ? 'its rings' : 'its board';
      return 'Both boards found. Drag an outline to fit $fit if needed (only when no one is throwing), '
          'then lock them.';
    }
    if (drawn) {
      final again = missed ? 'That loop is too small or too flat for a board. ' : '';
      return "${again}Draw a finger round the edge of $next's board. "
          'Any knife that sticks inside counts: the time wins, not the score.';
    }
    final again = missed ? 'No board found there. ' : '';
    return "${again}Tap the centre of $next's board.";
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
/// taps on the picture, as fractions of its width and height. With [onDraw]
/// instead, a finger drawn round a board ([LoopDrawer]). While
/// [onAdjust] is set (both boards found, not locked: backlog #10), the
/// outlines can be dragged instead, as the single target's can
/// ([BoardsEditor]).
class BoardsOverlay extends StatelessWidget {
  const BoardsOverlay({
    super.key,
    required this.targets,
    this.onTap,
    this.onDraw,
    this.onAdjust,
    this.tapsOff,
    this.throws,
    this.go = Duration.zero,
  });

  final QuickDrawTargets targets;
  final ValueChanged<Point2>? onTap;

  /// A loop drawn round a board, as fractions of the picture each way.
  final ValueChanged<List<Point2>>? onDraw;

  /// Player N's board, dragged into place.
  final void Function(int player, TargetCalibration board)? onAdjust;

  /// While true, taps are ignored (e.g. while a recording plays).
  final ValueListenable<bool>? tapsOff;

  /// Each player's throw so far, while a game is played: shown under their
  /// board, timed from [go] ([boardLines]).
  final ValueListenable<List<QuickDrawThrow?>>? throws;
  final Duration go;

  @override
  Widget build(BuildContext context) {
    final adjust = onAdjust;
    if (adjust != null) return BoardsEditor(targets: targets, onAdjust: adjust);
    final played = throws;
    final paint = played == null
        ? CustomPaint(size: Size.infinite, painter: BoardsPainter(targets))
        : ValueListenableBuilder(
            valueListenable: played,
            builder: (context, list, _) =>
                CustomPaint(size: Size.infinite, painter: BoardsPainter(targets, results: boardLines(list, go))),
          );
    final tap = onTap, draw = onDraw;
    if (tap == null && draw == null) return paint;
    Widget tappable(Widget child) => draw != null
        ? LoopDrawer(onDraw: draw, child: child)
        : LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            key: const Key('quickDrawBoardTap'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => tap!(Point2(
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

/// A finger drawn round a board, over [child]: the path follows the finger,
/// and on lift [onDraw] gets the loop as fractions of the area each way.
class LoopDrawer extends StatefulWidget {
  const LoopDrawer({super.key, required this.onDraw, required this.child});

  final ValueChanged<List<Point2>> onDraw;
  final Widget child;

  @override
  State<LoopDrawer> createState() => _LoopDrawerState();
}

class _LoopDrawerState extends State<LoopDrawer> {
  final _points = <Offset>[];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          key: const Key('quickDrawBoardDraw'),
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => setState(() => _points
            ..clear()
            ..add(d.localPosition)),
          onPanUpdate: (d) => setState(() => _points.add(d.localPosition)),
          onPanEnd: (_) {
            final loop = [
              for (final p in _points) Point2(p.dx / constraints.maxWidth, p.dy / constraints.maxHeight),
            ];
            setState(_points.clear);
            widget.onDraw(loop);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              CustomPaint(size: Size.infinite, painter: _TrailPainter(List.of(_points))),
            ],
          ),
        ),
      );
}

/// The finger's path so far.
class _TrailPainter extends CustomPainter {
  _TrailPainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    canvas.drawPoints(
      PointMode.polygon,
      points,
      Paint()
        ..color = Colors.lightBlueAccent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.points.length != points.length;
}

/// Both boards' outlines, draggable (backlog #10): a touch picks up the
/// board under the finger ([grabAt]: a handle first, else the board whose
/// centre is nearest), and dragging moves, turns or stretches that board
/// alone, as on the single target ([CalibrationEditor]).
class BoardsEditor extends StatefulWidget {
  const BoardsEditor({super.key, required this.targets, required this.onAdjust});

  final QuickDrawTargets targets;
  final void Function(int player, TargetCalibration board) onAdjust;

  @override
  State<BoardsEditor> createState() => _BoardsEditorState();
}

class _BoardsEditorState extends State<BoardsEditor> {
  /// The board being dragged, and what of it.
  (int, CalibrationGrab)? _drag;
  var _scale = 1.0;

  Point2 _toImage(Offset o) => Point2(o.dx / _scale, o.dy / _scale);

  void _start(Offset at) {
    final p = _toImage(at);
    final reach = CalibrationEditor.handleReach / _scale;
    (int, CalibrationGrab)? best;
    var bestRank = double.infinity;
    for (final (i, board) in widget.targets.boards.indexed) {
      final grab = grabAt(board, p, reach);
      if (grab == null) continue;
      // A handle beats a body; between bodies, the one whose centre is nearest.
      final rank = grab == CalibrationGrab.move ? 1 + board.outer.normalisedRadius(p) : 0.0;
      if (rank < bestRank) (best, bestRank) = ((i, grab), rank);
    }
    _drag = best;
  }

  void _update(DragUpdateDetails d) {
    final drag = _drag;
    if (drag == null) return;
    final (i, grab) = drag;
    final board = widget.targets.boards[i];
    widget.onAdjust(i, dragged(board, grab, delta: _toImage(d.delta), at: _toImage(d.localPosition)));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final boards = widget.targets.boards;
          if (boards.isNotEmpty) _scale = constraints.maxWidth / boards.first.imageWidth;
          return GestureDetector(
            key: const Key('boardsEditor'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _start(d.localPosition),
            onPanUpdate: _update,
            onPanEnd: (_) => _drag = null,
            child: CustomPaint(size: Size.infinite, painter: BoardsPainter(widget.targets, handles: true)),
          );
        },
      );
}

/// The line under each board: the throw's time after [go] and its score,
/// "bounced" or "false start" ([judgedText]); null until its throw is in.
List<String?> boardLines(List<QuickDrawThrow?> throws, Duration go) {
  final judged = judgeQuickDraw(throws, go).players;
  return [for (final (i, t) in throws.indexed) t == null ? null : judgedText(judged[i])];
}

/// Draws [QuickDrawTargets.boards] over the picture, each scaled from its own
/// image size to the size painted, with each player's [results] line under
/// their board. A board drawn round ([QuickDrawTargets.areas]) shows only its
/// outline: its rings are never scored.
class BoardsPainter extends CustomPainter {
  BoardsPainter(this.targets, {this.results = const [], this.handles = false});

  final QuickDrawTargets targets;
  final List<String?> results;

  /// Draw each board's two handles (while the outlines can be adjusted).
  final bool handles;

  @override
  void paint(Canvas canvas, Size size) {
    final colour = targets.locked ? Colors.greenAccent : Colors.lightBlueAccent;
    final stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final (i, board) in targets.boards.indexed) {
      final scale = size.width / board.imageWidth;
      for (final e in [if (!targets.areas.contains(i)) ...board.boundaries.values, board.outer]) {
        canvas.drawPath(_path(e.rescaled(scale)), stroke);
      }
      _label(canvas, board, scale, '${i + 1}', colour);
      if (handles) {
        for (final h in [board.majorHandle, board.minorHandle]) {
          final at = Offset(h.x * scale, h.y * scale);
          canvas.drawCircle(at, 12, Paint()..color = Colors.white);
          canvas.drawCircle(at, 12, stroke);
        }
      }
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
  bool shouldRepaint(BoardsPainter old) =>
      old.targets != targets || old.handles != handles || !listEquals(old.results, results);
}

/// Quick draw's **Names** button (named-players story, 2026-10-19): the two
/// throwers' names, the same as Play's ([playerNamesProvider]), changed in a
/// dialog before Start.
class NamesButton extends ConsumerWidget {
  const NamesButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton(
        key: const Key('quickDrawNames'),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.black54),
        onPressed: () => editPlayerNames(context, ref),
        child: const Text('Names'),
      );
}

/// Asks for both players' names, filled with the current ones; Save keeps
/// them (blank is "Player N"), Cancel changes nothing.
Future<void> editPlayerNames(BuildContext context, WidgetRef ref) async {
  final names = await showDialog<List<String>>(
    context: context,
    builder: (context) => _NamesDialog(ref.read(playerNamesProvider)),
  );
  if (names != null) ref.read(playerNamesProvider.notifier).set(names);
}

/// The Names dialog; it owns its fields, so they outlive its closing
/// animation.
class _NamesDialog extends StatefulWidget {
  const _NamesDialog(this.names);

  final List<String?> names;

  @override
  State<_NamesDialog> createState() => _NamesDialogState();
}

class _NamesDialogState extends State<_NamesDialog> {
  late final _fields = [for (final n in widget.names) TextEditingController(text: n ?? '')];

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Names'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, c) in _fields.indexed)
              TextField(
                key: Key('quickDrawName$i'),
                controller: c,
                decoration: InputDecoration(labelText: playerNumber(i), hintText: playerNumber(i)),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(maxNameLength)],
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            key: const Key('quickDrawNamesSave'),
            onPressed: () => Navigator.of(context).pop([for (final c in _fields) c.text]),
            child: const Text('Save'),
          ),
        ],
      );
}
