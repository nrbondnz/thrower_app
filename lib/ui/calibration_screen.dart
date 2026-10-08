import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/camera_frame.dart';
import '../camera/live_camera.dart';
import '../providers.dart';
import '../vision/ellipse.dart';
import '../vision/locate_in_frame.dart';
import '../vision/target_calibration.dart';
import '../vision/target_locator.dart';
import '../vision/target_mapping.dart';
import 'calibration_editor.dart';
import 'camera_screen.dart';

/// Point the mounted phone at the board and tap "Find target": the fitted ring
/// edges are drawn over the live preview. Drag them into place if needed, then
/// "Lock target". The lock lasts for the session (the camera doesn't move);
/// "Re-calibrate" unlocks it.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  FrameLocateResult? _found;
  bool _searching = false;
  int? _millis;

  /// Last tap on the locked target (image pixel) and its score.
  Point2? _tap;
  int? _tapScore;

  void _scoreTap(TargetCalibration calibration, Point2 at) {
    final point = TargetMapping(calibration).toTarget(at);
    setState(() {
      _tap = at;
      _tapScore = ref.read(targetModelProvider).scoreAt(point);
    });
  }

  void _clearTap() => setState(() => _tap = _tapScore = null);

  Future<void> _find(LiveCamera camera) async {
    setState(() => _searching = true);
    final stopwatch = Stopwatch()..start();
    final frame = await camera.frames().first;
    final rotation = camera.uprightRotation;
    final result = await compute(locateInFrame, (frame, rotation, ref.read(ringBoundaryRadiiProvider)));
    if (kDebugMode) await _dumpFrame(frame, rotation, result);
    if (!mounted) return;
    final calibration = calibrationFrom(result);
    if (calibration != null) ref.read(calibrationProvider.notifier).start(calibration);
    setState(() {
      _found = result;
      _searching = false;
      _millis = stopwatch.elapsedMilliseconds;
    });
  }

  /// Debug builds only: log the frame's layout and the result, and save the
  /// exact image the ring finder was given to the app's cache directory
  /// (fetch it with `adb exec-out run-as nz.nrbond.thrower cat cache/calibration-frame.png`).
  Future<void> _dumpFrame(CameraFrame frame, int rotation, FrameLocateResult result) async {
    final outcome = switch (result.result) {
      TargetFound(:final confidence) => 'found ${(confidence * 100).round()}%',
      TargetNotFound(:final reason) => 'not found: $reason',
    };
    debugPrint('Calibration frame: ${describeFrame(frame)}; rotation $rotation°; '
        'analysed ${result.imageWidth}×${result.imageHeight}; $outcome');
    final png = await compute(debugFramePng, (frame, rotation));
    if (png == null) return;
    final file = File('${Directory.systemTemp.path}/calibration-frame.png');
    await file.writeAsBytes(png);
    debugPrint('Calibration frame saved to ${file.path}');
  }

  @override
  Widget build(BuildContext context) {
    final camera = ref.watch(liveCameraProvider).value;
    final state = ref.watch(calibrationProvider);
    final notifier = ref.read(calibrationProvider.notifier);
    final locked = state?.locked ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Calibrate target')),
      body: Column(
        children: [
          Expanded(
            child: CameraView(
              overlayBuilder: (context, _) => state == null
                  ? const SizedBox.expand()
                  : CalibrationEditor(
                      calibration: state.calibration,
                      locked: locked,
                      onChanged: notifier.adjust,
                      onTapLocked: (at) => _scoreTap(state.calibration, at),
                      marker: locked ? _tap : null,
                    ),
            ),
          ),
          CalibrationControls(
            status: locked
                ? lockedStatus(_tapScore)
                : calibrationStatus(_found, searching: _searching, millis: _millis),
            canAdjust: state != null && !locked,
            locked: locked,
            onFind: camera == null || _searching || locked ? null : () => _find(camera),
            onLock: notifier.lock,
            onUnlock: () {
              _clearTap();
              notifier.unlock();
            },
            findLabel: state == null ? 'Find target' : 'Find again',
          ),
        ],
      ),
    );
  }
}

/// Status, the safety reminder while adjusting, and the buttons.
class CalibrationControls extends StatelessWidget {
  const CalibrationControls({
    super.key,
    required this.status,
    required this.canAdjust,
    required this.locked,
    required this.onFind,
    required this.onLock,
    required this.onUnlock,
    required this.findLabel,
  });

  final String status;
  final bool canAdjust;
  final bool locked;
  final VoidCallback? onFind;
  final VoidCallback onLock;
  final VoidCallback onUnlock;
  final String findLabel;

  /// Shown whenever the outline can be adjusted: the phone sits beside the
  /// board, so adjusting means standing near the throwing lane.
  static const safetyNote = 'Only adjust when no one is throwing.';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            status,
            key: const Key('calibrationStatus'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          if (canAdjust) ...[
            const SizedBox(height: 8),
            const Text(
              'Drag inside the rings to move them, or drag a white handle to reshape.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber, color: Colors.amber),
                SizedBox(width: 8),
                Text(safetyNote, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            alignment: WrapAlignment.center,
            children: [
              if (locked)
                FilledButton(onPressed: onUnlock, child: const Text('Re-calibrate'))
              else ...[
                OutlinedButton(onPressed: onFind, child: Text(findLabel)),
                if (canAdjust) FilledButton(onPressed: onLock, child: const Text('Lock target')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A calibration to start adjusting from: the target if found, or the ring
/// finder's rejected attempt (so a near miss can be fixed by hand). Null if
/// there's nothing to show.
TargetCalibration? calibrationFrom(FrameLocateResult found) {
  switch (found.result) {
    case TargetFound(:final boundaries, :final outer):
      return TargetCalibration(
        imageWidth: found.imageWidth,
        imageHeight: found.imageHeight,
        boundaries: boundaries,
        outer: outer,
      );
    case TargetNotFound(:final attempted):
      if (attempted.isEmpty) return null;
      final r = attempted.keys.reduce(math.max);
      return TargetCalibration(
        imageWidth: found.imageWidth,
        imageHeight: found.imageHeight,
        boundaries: attempted,
        outer: attempted[r]!.scaled(1 / r),
      );
  }
}

/// What to tell the user once the target is locked: how to test scoring, or
/// the score of the last tap.
String lockedStatus(int? tapScore) => tapScore == null
    ? 'Target locked. Tap the picture to test scoring.'
    : 'Score here: $tapScore${tapScore == 0 ? ' (outside the target)' : ''}. Tap again to test another spot.';

/// What to tell the user about the latest search.
String calibrationStatus(FrameLocateResult? found, {required bool searching, int? millis}) {
  if (searching) return 'Looking for the target…';
  final time = millis == null ? '' : ' ($millis ms)';
  return switch (found?.result) {
    null => 'Point the phone at the board, then tap Find target.',
    TargetFound(:final confidence) => 'Target found: confidence ${(confidence * 100).round()}%$time',
    TargetNotFound(:final reason, :final attempted) => attempted.isEmpty
        ? 'Target not found: $reason$time'
        : 'Not sure about the target ($reason)$time. Adjust the rings by hand, or find again.',
  };
}
