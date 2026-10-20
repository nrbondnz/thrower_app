import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/camera_frame.dart';
import '../camera/target_camera.dart';
import '../game/find_target.dart';
import '../providers.dart';
import '../vision/ellipse.dart';
import '../vision/entry_point.dart';
import '../vision/locate_in_frame.dart';
import '../vision/tapped_target_locator.dart';
import '../vision/target_calibration.dart';
import '../vision/target_locator.dart';
import '../vision/target_mapping.dart';
import 'calibration_editor.dart';
import 'camera_view.dart';
import 'watch_status.dart';

/// Point the mounted phone at the board and tap "Find target": the camera
/// zooms in on the board and the fitted ring edges are drawn over the live
/// preview. Drag them into place if needed, then
/// "Lock target". The lock lasts for the session (the camera doesn't move);
/// "Re-calibrate" unlocks it.
///
/// If Find target can't find the rings (stencilled rings with gaps: Mark's
/// boards, 2026-10-21) or finds the wrong board, **Tap the board**, then tap
/// the board's middle: the rings are looked for there ([locateTargetAt]),
/// at the zoom the camera has.
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
      _knife = false;
    });
  }

  void _clearTap() => setState(() {
        _tap = _tapScore = null;
        _knife = false;
      });

  /// Whether the marker is a detected knife's entry (rather than a tap).
  var _knife = false;

  /// Tap the board: the next tap on the picture is the board's middle.
  var _tapMode = false;

  /// Tap the board: looks for the rings around [at] (fractions of the
  /// picture's width and height), on the camera's next frame.
  Future<void> _findAt(TargetCamera camera, Point2 at) async {
    setState(() {
      _tapMode = false;
      _searching = true;
    });
    final stopwatch = Stopwatch()..start();
    final frame = await camera.frames().first;
    final tapped = await compute(
        locateTappedInFrame, (frame, camera.uprightRotation, ref.read(ringBoundaryRadiiProvider), [at]));
    if (!mounted) return;
    final found = FrameLocateResult(tapped.boards.single, tapped.imageWidth, tapped.imageHeight);
    final calibration = calibrationFrom(found);
    if (calibration != null) ref.read(calibrationProvider.notifier).start(calibration, zoom: camera.zoom);
    setState(() {
      _found = found;
      _zoom = camera.zoom;
      _offCentre = false;
      _searching = false;
      _millis = stopwatch.elapsedMilliseconds;
    });
  }

  void _scoreKnife(TargetCalibration calibration, EntryEstimate? entry) {
    if (entry == null) {
      setState(() {
        _tap = _tapScore = null;
        _knife = true;
      });
      return;
    }
    _scoreTap(calibration, entry.point);
    setState(() => _knife = true);
  }

  /// The zoom the last search ended at, and whether the board's position
  /// held it back (so the user can be told to centre the board).
  double _zoom = 1;
  bool _offCentre = false;

  /// Find target, zooming the camera in on the board ([findTarget]).
  Future<void> _find(TargetCamera camera) async {
    setState(() => _searching = true);
    final stopwatch = Stopwatch()..start();
    final found = await findTarget(camera, _locate);
    if (!mounted) return;
    final calibration = calibrationFrom(found.found);
    if (calibration != null) ref.read(calibrationProvider.notifier).start(calibration, zoom: found.zoom);
    setState(() {
      _found = found.found;
      _zoom = found.zoom;
      _offCentre = found.offCentre;
      _searching = false;
      _millis = stopwatch.elapsedMilliseconds;
    });
  }

  Future<FrameLocateResult> _locate(TargetCamera camera) async {
    final frame = await camera.frames().first;
    final rotation = camera.uprightRotation;
    final result = await compute(locateInFrame, (frame, rotation, ref.read(ringBoundaryRadiiProvider)));
    if (kDebugMode) await _dumpFrame(frame, rotation, result);
    return result;
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
    final camera = ref.watch(cameraProvider).value;
    final state = ref.watch(calibrationProvider);
    final notifier = ref.read(calibrationProvider.notifier);
    final locked = state?.locked ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Calibrate target')),
      // Keep content above the system navigation bar (Android 15 draws apps
      // edge to edge) and the iPhone home indicator; the AppBar handles the top.
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: CameraView(
                overlayBuilder: (context, camera) => _tapMode
                    ? LayoutBuilder(
                        builder: (context, constraints) => GestureDetector(
                          key: const Key('calibrationTapArea'),
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => _findAt(
                            camera,
                            Point2(d.localPosition.dx / constraints.maxWidth, d.localPosition.dy / constraints.maxHeight),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      )
                    : state == null
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
            if (locked && camera != null && state != null)
              Container(
                color: Colors.black,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 12),
                child: WatchStatus(
                  camera: camera,
                  calibration: state.calibration,
                  onKnifeEntry: (entry) => _scoreKnife(state.calibration, entry),
                ),
              ),
            CalibrationControls(
              status: locked
                  ? lockedStatus(_tapScore, knife: _knife)
                  : _tapMode
                      ? tapTheBoardStatus
                      : calibrationStatus(_found,
                          searching: _searching, millis: _millis, zoom: _zoom, offCentre: _offCentre),
              canAdjust: state != null && !locked && !_tapMode,
              locked: locked,
              tapMode: _tapMode,
              onFind: camera == null || _searching || locked ? null : () => _find(camera),
              onTapBoard: camera == null || _searching || locked ? null : () => setState(() => _tapMode = !_tapMode),
              onLock: notifier.lock,
              onUnlock: () {
                _clearTap();
                notifier.unlock();
              },
              findLabel: state == null ? 'Find target' : 'Find again',
            ),
          ],
        ),
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
    this.tapMode = false,
    this.onTapBoard,
  });

  final String status;
  final bool canAdjust;
  final bool locked;
  final VoidCallback? onFind;

  /// Waiting for a tap on the board's middle ([onTapBoard] toggles it).
  final bool tapMode;
  final VoidCallback? onTapBoard;
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
          if (canAdjust || tapMode) ...[
            const SizedBox(height: 8),
            if (canAdjust)
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
                OutlinedButton(onPressed: tapMode ? null : onFind, child: Text(findLabel)),
                OutlinedButton(
                  key: const Key('calibrationTapBoard'),
                  onPressed: onTapBoard,
                  child: Text(tapMode ? 'Cancel tap' : 'Tap the board'),
                ),
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

/// What to tell the user while waiting for the tap on the board.
const tapTheBoardStatus = 'Tap the middle of the board in the picture.';

/// What to tell the user once the target is locked: how to test scoring, or
/// the score of the last tap.
String lockedStatus(int? tapScore, {bool knife = false}) {
  if (knife) {
    return tapScore == null
        ? "Knife stuck, but couldn't find where it went in."
        : 'Knife went in at the yellow dot: scores $tapScore${tapScore == 0 ? ' (outside the target)' : ''}.';
  }
  return tapScore == null
      ? 'Target locked. Tap the picture to test scoring.'
      : 'Score here: $tapScore${tapScore == 0 ? ' (outside the target)' : ''}. Tap again to test another spot.';
}

/// What to tell the user about the latest search: found at [zoom], and
/// whether centring the board ([offCentre]) would let the camera zoom closer.
String calibrationStatus(
  FrameLocateResult? found, {
  required bool searching,
  int? millis,
  double zoom = 1,
  bool offCentre = false,
}) {
  if (searching) return 'Looking for the target…';
  final time = millis == null ? '' : ' ($millis ms)';
  final zoomed = zoom > 1 ? ', zoomed in ${zoom.toStringAsFixed(1)}×' : '';
  final tip = offCentre ? '\nCentre the board in the picture for a closer view.' : '';
  return switch (found?.result) {
    null => 'Point the phone at the board, then tap Find target.',
    TargetFound(:final confidence) => 'Target found: confidence ${(confidence * 100).round()}%$zoomed$time$tip',
    TargetNotFound(:final reason, :final attempted) => attempted.isEmpty
        ? 'Target not found: $reason$time. Try Tap the board.'
        : 'Not sure about the target ($reason)$time. Adjust the rings by hand, find again, or tap the board.',
  };
}
