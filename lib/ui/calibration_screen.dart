import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/live_camera.dart';
import '../providers.dart';
import '../vision/ellipse.dart';
import '../vision/locate_in_frame.dart';
import '../vision/target_locator.dart';
import 'camera_screen.dart';

/// Point the mounted phone at the board, tap "Find target", and the fitted
/// ring edges are drawn over the live preview.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  FrameLocateResult? _found;
  bool _searching = false;
  int? _millis;

  Future<void> _find(LiveCamera camera) async {
    setState(() => _searching = true);
    final stopwatch = Stopwatch()..start();
    final frame = await camera.frames().first;
    final result = await compute(locateInFrame, (frame, camera.uprightRotation, ref.read(ringBoundaryRadiiProvider)));
    if (!mounted) return;
    setState(() {
      _found = result;
      _searching = false;
      _millis = stopwatch.elapsedMilliseconds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final camera = ref.watch(liveCameraProvider).value;
    final found = _found;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Calibrate target')),
      body: Column(
        children: [
          Expanded(
            child: CameraView(
              overlayBuilder: (context, _) => found == null
                  ? const SizedBox.expand()
                  : CustomPaint(size: Size.infinite, painter: RingOverlayPainter(found)),
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  calibrationStatus(found, searching: _searching, millis: _millis),
                  key: const Key('calibrationStatus'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: camera == null || _searching ? null : () => _find(camera),
                  child: Text(found == null ? 'Find target' : 'Find again'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What to tell the user about the latest search.
String calibrationStatus(FrameLocateResult? found, {required bool searching, int? millis}) {
  if (searching) return 'Looking for the target…';
  final time = millis == null ? '' : ' ($millis ms)';
  return switch (found?.result) {
    null => 'Point the phone at the board, then tap Find target.',
    TargetFound(:final confidence) => 'Target found: confidence ${(confidence * 100).round()}%$time',
    TargetNotFound(:final reason) => 'Target not found: $reason$time',
  };
}

/// Draws the fitted ring edges (blue) over the preview, or a rejected attempt
/// (magenta), scaled from the image the finder ran on to the preview's size.
class RingOverlayPainter extends CustomPainter {
  RingOverlayPainter(this.found);

  final FrameLocateResult found;

  @override
  void paint(Canvas canvas, Size size) {
    if (found.imageWidth == 0) return;
    final scale = size.width / found.imageWidth;
    final (ellipses, colour) = switch (found.result) {
      TargetFound(:final boundaries, :final outer) => ([...boundaries.values, outer], Colors.blueAccent),
      TargetNotFound(:final attempted) => (attempted.values.toList(), Colors.purpleAccent),
    };
    final stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final e in ellipses) {
      canvas.drawPath(_path(e.rescaled(scale)), stroke);
    }
  }

  Path _path(Ellipse e) {
    final path = Path();
    for (var i = 0; i <= 120; i++) {
      final p = e.pointAt(2 * 3.141592653589793 * i / 120);
      i == 0 ? path.moveTo(p.x, p.y) : path.lineTo(p.x, p.y);
    }
    return path;
  }

  @override
  bool shouldRepaint(RingOverlayPainter old) => old.found != found;
}
