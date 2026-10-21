import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../vision/ellipse.dart';
import '../vision/target_calibration.dart';

/// Draws a calibration's ring edges over the camera preview (sized exactly
/// over it) and, unless [locked], lets the user correct them: drag inside the
/// target to move it, or drag a handle on the outer ring to turn/stretch its
/// long axis or stretch its short axis.
class CalibrationEditor extends StatefulWidget {
  const CalibrationEditor({
    super.key,
    required this.calibration,
    required this.locked,
    required this.onChanged,
    this.onTapLocked,
    this.marker,
  });

  final TargetCalibration calibration;
  final bool locked;
  final ValueChanged<TargetCalibration> onChanged;

  /// Once locked, a tap on the picture reports its image pixel (to score it).
  final ValueChanged<Point2>? onTapLocked;

  /// An image pixel to mark (e.g. the last tap).
  final Point2? marker;

  /// How close (screen pixels) a touch must be to grab a handle.
  static const handleReach = 32.0;

  @override
  State<CalibrationEditor> createState() => _CalibrationEditorState();
}

/// What a drag on a calibration's outline picks up: the whole target, or
/// one of its outer ring's handles.
enum CalibrationGrab {
  move,
  major,
  minor,
  // A four-cornered board's corners (story-checkpoint-board-outlines).
  corner0,
  corner1,
  corner2,
  corner3;

  static const corners = [corner0, corner1, corner2, corner3];

  /// Which corner, or null for the other grabs.
  int? get corner => index >= corner0.index ? index - corner0.index : null;
}

/// What a touch at [at] (image pixels) picks up on [c]: the nearer handle
/// within [reach] (image pixels), unless the touch is nearer the target's
/// centre than that handle (a small target on screen: the touch zones
/// overlap, and the middle should move it); else the target if the touch is
/// inside its outer ring (or just outside it); null for neither. Shared by
/// [CalibrationEditor] and the two-board editor.
///
/// A four-cornered board ([TargetCalibration.outline]) has a handle on each
/// corner instead, and is moved from inside its outline.
CalibrationGrab? grabAt(TargetCalibration c, Point2 at, double reach) {
  double distance(Point2 p) => math.sqrt((at.x - p.x) * (at.x - p.x) + (at.y - p.y) * (at.y - p.y));
  if (c.outline case final corners?) {
    final shape = c.shape;
    var nearest = 0;
    for (var i = 1; i < corners.length && i < CalibrationGrab.corners.length; i++) {
      if (distance(corners[i]) < distance(corners[nearest])) nearest = i;
    }
    final toCorner = distance(corners[nearest]);
    final inside = shape.reach(at) <= 1.1;
    if (toCorner <= reach && (!inside || toCorner < distance(shape.centre))) return CalibrationGrab.corners[nearest];
    return inside ? CalibrationGrab.move : null;
  }
  final toMajor = distance(c.majorHandle), toMinor = distance(c.minorHandle);
  final handle = toMajor <= toMinor ? (CalibrationGrab.major, toMajor) : (CalibrationGrab.minor, toMinor);
  final inside = c.outer.normalisedRadius(at) <= 1.1;
  if (handle.$2 <= reach && (!inside || handle.$2 < distance(Point2(c.outer.cx, c.outer.cy)))) return handle.$1;
  return inside ? CalibrationGrab.move : null;
}

/// [c] after a drag of what [grab] picked up: moved by [delta], or with the
/// handle at [at] (image pixels).
TargetCalibration dragged(TargetCalibration c, CalibrationGrab grab, {required Point2 delta, required Point2 at}) =>
    switch (grab) {
      CalibrationGrab.move => c.moved(delta.x, delta.y),
      CalibrationGrab.major => c.withMajorHandleAt(at),
      CalibrationGrab.minor => c.withMinorHandleAt(at),
      _ => c.withCornerAt(grab.corner!, at),
    };

class _CalibrationEditorState extends State<CalibrationEditor> {
  CalibrationGrab? _drag;
  late double _scale;

  Point2 _toImage(Offset o) => Point2(o.dx / _scale, o.dy / _scale);

  void _start(Offset at) => _drag = grabAt(widget.calibration, _toImage(at), CalibrationEditor.handleReach / _scale);

  void _update(DragUpdateDetails d) {
    final grab = _drag;
    if (grab == null) return;
    widget.onChanged(
      dragged(widget.calibration, grab, delta: _toImage(d.delta), at: _toImage(d.localPosition)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _scale = constraints.maxWidth / widget.calibration.imageWidth;
        final paint = CustomPaint(
          size: Size.infinite,
          painter: CalibrationPainter(widget.calibration, scale: _scale, locked: widget.locked, marker: widget.marker),
        );
        if (widget.locked) {
          final onTap = widget.onTapLocked;
          if (onTap == null) return paint;
          return GestureDetector(
            key: const Key('scoreTapArea'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => onTap(_toImage(d.localPosition)),
            child: paint,
          );
        }
        return GestureDetector(
          key: const Key('calibrationEditor'),
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _start(d.localPosition),
          onPanUpdate: _update,
          onPanEnd: (_) => _drag = null,
          child: paint,
        );
      },
    );
  }
}

/// Ring edges in blue with two handles while adjusting; green once locked.
class CalibrationPainter extends CustomPainter {
  CalibrationPainter(this.calibration, {required this.scale, required this.locked, this.marker});

  final TargetCalibration calibration;
  final double scale;
  final bool locked;
  final Point2? marker;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = locked ? Colors.greenAccent : Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final e in [...calibration.boundaries.values, calibration.outer]) {
      canvas.drawPath(_path(e.rescaled(scale)), stroke);
    }
    final m = marker;
    if (m != null) {
      final at = Offset(m.x * scale, m.y * scale);
      canvas.drawCircle(at, 9, Paint()..color = Colors.black);
      canvas.drawCircle(at, 6, Paint()..color = Colors.yellowAccent);
    }
    if (locked) return;
    for (final h in [calibration.majorHandle, calibration.minorHandle]) {
      final at = Offset(h.x * scale, h.y * scale);
      canvas.drawCircle(at, 12, Paint()..color = Colors.white);
      canvas.drawCircle(at, 12, stroke);
    }
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
  bool shouldRepaint(CalibrationPainter old) =>
      old.calibration != calibration || old.scale != scale || old.locked != locked || old.marker != marker;
}
