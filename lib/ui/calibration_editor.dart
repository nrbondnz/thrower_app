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
  });

  final TargetCalibration calibration;
  final bool locked;
  final ValueChanged<TargetCalibration> onChanged;

  /// How close (screen pixels) a touch must be to grab a handle.
  static const handleReach = 32.0;

  @override
  State<CalibrationEditor> createState() => _CalibrationEditorState();
}

enum _Drag { move, major, minor }

class _CalibrationEditorState extends State<CalibrationEditor> {
  _Drag? _drag;
  late double _scale;

  Point2 _toImage(Offset o) => Point2(o.dx / _scale, o.dy / _scale);
  Offset _toScreen(Point2 p) => Offset(p.x * _scale, p.y * _scale);

  void _start(Offset at) {
    final c = widget.calibration;
    if ((at - _toScreen(c.majorHandle)).distance <= CalibrationEditor.handleReach) {
      _drag = _Drag.major;
    } else if ((at - _toScreen(c.minorHandle)).distance <= CalibrationEditor.handleReach) {
      _drag = _Drag.minor;
    } else if (c.outer.normalisedRadius(_toImage(at)) <= 1.1) {
      _drag = _Drag.move;
    } else {
      _drag = null;
    }
  }

  void _update(DragUpdateDetails d) {
    final c = widget.calibration;
    final next = switch (_drag) {
      _Drag.move => c.moved(d.delta.dx / _scale, d.delta.dy / _scale),
      _Drag.major => c.withMajorHandleAt(_toImage(d.localPosition)),
      _Drag.minor => c.withMinorHandleAt(_toImage(d.localPosition)),
      null => null,
    };
    if (next != null) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _scale = constraints.maxWidth / widget.calibration.imageWidth;
        final paint = CustomPaint(
          size: Size.infinite,
          painter: CalibrationPainter(widget.calibration, scale: _scale, locked: widget.locked),
        );
        if (widget.locked) return paint;
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
  CalibrationPainter(this.calibration, {required this.scale, required this.locked});

  final TargetCalibration calibration;
  final double scale;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = locked ? Colors.greenAccent : Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final e in [...calibration.boundaries.values, calibration.outer]) {
      canvas.drawPath(_path(e.rescaled(scale)), stroke);
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
      old.calibration != calibration || old.scale != scale || old.locked != locked;
}
