import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'camera_frame.dart';
import 'cropped_camera.dart';
import 'target_camera.dart';

/// Every frame of [source], in order, at the pace its listener can take them:
/// each arriving frame is kept as a compact copy ([compactFrame]) in a queue,
/// and handed on one at a time, with a turn of the event loop between (so
/// the screen keeps drawing). A live camera can't be asked for a frame again,
/// so this is how Quick draw analyses every frame on a phone too slow to keep
/// up: it falls behind and reports late, but skips nothing (Nigel,
/// 2026-10-15, "analysis can come back with the actual result 1/2 second
/// later"). Wrap a crop ([CroppedCamera]), not a whole frame: a kept board
/// crop is 0.2–2 MB (a 250–720 px square; BGRA on iOS is 4 bytes a pixel,
/// YUV on Android 1.5).
///
/// Frames keep their own timestamps (when they arrived from the camera).
/// Past [maxBytes] of frames waiting, the oldest are dropped and counted in
/// [dropped]: a guard against running out of memory (Review Agent,
/// 2026-10-15: a 600-frame cap could reach 1–2.5 GB with large crops on a
/// phone that never catches up). 75 MB holds 1.2–6 s at 60 fps, depending on
/// the crop.
class QueuedCamera implements TargetCamera {
  QueuedCamera(this.source, {this.maxBytes = 75 * 1024 * 1024});

  final TargetCamera source;
  final int maxBytes;

  /// Frames waiting to be handed on.
  final waiting = ValueNotifier(0);

  /// Frames dropped because the queue was full.
  var dropped = 0;

  final _queue = Queue<CameraFrame>();
  var _bytes = 0;

  static int _sizeOf(CameraFrame f) => f.planes.fold(0, (n, p) => n + p.bytes.length);
  StreamController<CameraFrame>? _out;
  StreamSubscription<CameraFrame>? _in;
  var _busy = false;
  Duration? _newest, _handedOn;

  /// How far behind the camera the frames being handed on are.
  Duration get behind {
    final newest = _newest, handed = _handedOn;
    return newest == null || handed == null ? Duration.zero : newest - handed;
  }

  void _onFrame(CameraFrame frame) {
    final copy = compactFrame(frame);
    _bytes += _sizeOf(copy);
    _queue.add(copy);
    while (_bytes > maxBytes && _queue.length > 1) {
      _bytes -= _sizeOf(_queue.removeFirst());
      dropped++;
    }
    _newest = frame.timestamp;
    waiting.value = _queue.length;
    _pump();
  }

  Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_queue.isNotEmpty) {
        final out = _out;
        if (out == null || out.isClosed) return;
        final frame = _queue.removeFirst();
        _bytes -= _sizeOf(frame);
        waiting.value = _queue.length;
        _handedOn = frame.timestamp;
        out.add(frame);
        // Let the listener take this frame, and the screen draw, before the next.
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Stream<CameraFrame> frames() => (_out ??= StreamController<CameraFrame>.broadcast(
        onListen: () => _in ??= source.frames().listen(_onFrame),
        onCancel: () async {
          await _in?.cancel();
          _in = null;
        },
      ))
          .stream;

  @override
  int get uprightRotation => source.uprightRotation;

  @override
  int get minChange => source.minChange;

  @override
  double get maxZoom => 1;

  @override
  Duration get now => source.now;

  @override
  double get zoom => 1;

  @override
  Future<void> setZoom(double level) async {}

  /// Takes no more frames from the source; those already waiting are still
  /// handed on (Quick draw stops feeding at the end of its result window, so
  /// a phone that can't keep up still finishes).
  Future<void> stopTaking() async {
    await _in?.cancel();
    _in = null;
  }

  /// Stops listening to the source (which belongs to whoever made this).
  @override
  Future<void> dispose() async {
    await _in?.cancel();
    _in = null;
    _queue.clear();
    _bytes = 0;
    await _out?.close();
    _out = null;
  }
}
