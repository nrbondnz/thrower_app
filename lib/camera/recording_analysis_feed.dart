import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'camera_frame.dart';
import 'recorded_camera.dart';
import 'target_camera.dart';

/// **Every** frame of a [RecordedCamera]'s recording, in order, for analysis,
/// each stamped with its place in the recording (frame number ÷ frame rate).
///
/// What's on screen may skip frames to keep up with the sound (the camera
/// decodes only the newest frame when it falls behind: the iPhone showed ~42
/// of the Quick draw clip's 60 a second, the Samsung A06 11–12), and a
/// skipped frame can hold the moment a knife lands. This feed decodes its own
/// copy of each frame, one after another, never ahead of what has been
/// shown, so analysis may finish **late** but never misses a frame or times
/// one by when it happened to arrive (Nigel, 2026-10-15: "analysis can come
/// back with the actual result 1/2 second later").
///
/// It follows the camera: when playback starts again from the beginning, it
/// starts again from the first frame. Frames are decoded only while someone
/// listens.
class RecordingAnalysisFeed implements TargetCamera {
  RecordingAnalysisFeed(this.camera, {FrameDecoder? decoder}) : decoder = decoder ?? camera.decoder {
    _lastPosition = camera.position.value;
    camera.position.addListener(_onPosition);
  }

  final RecordedCamera camera;
  final FrameDecoder decoder;

  /// The last frame analysed, or -1 before the first (for showing how far
  /// behind analysis is).
  final analysed = ValueNotifier(-1);

  StreamController<CameraFrame>? _frames;
  var _next = 0;
  var _busy = false;
  var _generation = 0;
  var _disposed = false;
  late Duration _lastPosition;

  /// The time of frame [index] in the recording.
  Duration timeOf(int index) => Duration(microseconds: index * 1000000 ~/ camera.pack.fps);

  /// The last frame shown so far (analysis doesn't go beyond it).
  int get _shown {
    final p = camera.position.value;
    return math.min(camera.pack.frameCount - 1, (p.inMicroseconds * camera.pack.fps + 500000) ~/ 1000000);
  }

  void _onPosition() {
    final p = camera.position.value;
    if (p < _lastPosition) {
      // Played again from the start: analyse again from the first frame.
      _generation++;
      _next = 0;
      analysed.value = -1;
    }
    _lastPosition = p;
    _pump();
  }

  /// Decodes and delivers frames in order up to the one on show, one at a
  /// time (decoding is asynchronous).
  Future<void> _pump() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      while (!_disposed && _next <= _shown && (_frames?.hasListener ?? false)) {
        final generation = _generation, index = _next;
        final decoded = await decoder(camera.pack.jpeg(index));
        decoded?.image?.dispose(); // Only the pixels are needed.
        if (_disposed || generation != _generation) continue; // Restarted meanwhile.
        _next = index + 1;
        if (decoded == null) continue;
        analysed.value = index;
        _frames?.add(CameraFrame(
          width: decoded.width,
          height: decoded.height,
          format: FrameFormat.bgra8888,
          planes: [FramePlane(bytes: decoded.bgra, bytesPerRow: decoded.width * 4, bytesPerPixel: 4)],
          timestamp: timeOf(index),
        ));
      }
    } catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s, library: 'recording analysis'));
    } finally {
      _busy = false;
    }
  }

  @override
  Stream<CameraFrame> frames() {
    final controller = _frames ??= StreamController<CameraFrame>.broadcast(onListen: _pump);
    return controller.stream;
  }

  @override
  int get uprightRotation => camera.uprightRotation;

  @override
  int get minChange => camera.minChange;

  @override
  double get maxZoom => 1;

  @override
  double get zoom => 1;

  @override
  Future<void> setZoom(double level) async {}

  /// Stops following the camera (which belongs to whoever made this).
  @override
  Future<void> dispose() async {
    _disposed = true;
    camera.position.removeListener(_onPosition);
    await _frames?.close();
    _frames = null;
  }
}
