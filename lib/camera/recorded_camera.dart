import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'camera_frame.dart';
import 'frame_pack.dart';
import 'target_camera.dart';

/// A recording the Live test can play, bundled with the app.
class Recording {
  const Recording({required this.name, required this.description, required this.asset});

  final String name;
  final String description;

  /// A [FramePack] asset.
  final String asset;
}

/// The two real boards from Nigel's video (2026-10-11), cropped one per board:
/// `docs/thrower/reference/live-camera/`.
const liveTestRecordings = [
  Recording(
    name: 'Target 1',
    description: 'Red rings on wood, dark bull',
    asset: 'assets/live/target1.tfrm',
  ),
  Recording(
    name: 'Target 2',
    description: 'Green and red rings, red bull',
    asset: 'assets/live/target2.tfrm',
  ),
];

/// One decoded frame for the preview: RGBA, row by row.
class RecordedFrame {
  const RecordedFrame(this.index, this.width, this.height, this.rgba);

  final int index;
  final int width;
  final int height;
  final Uint8List rgba;
}

/// Where playback time comes from; tests replace it.
typedef PlaybackClock = Duration Function();

/// Plays a [FramePack] as if it were a camera: like the live camera it runs
/// all the time, delivering a frame (BGRA, already upright) every
/// 1 / fps seconds to whoever listens, stamped with a monotonic clock.
///
/// It opens **paused on the first frame** (so the board can be calibrated
/// before anything happens); [restart] plays from the start, and it stops on
/// the last frame. Frames are decoded only when the position moves on.
class RecordedCamera implements TargetCamera {
  RecordedCamera(this.pack, {required this.recording, PlaybackClock? clock, bool autoTick = true})
      : _now = clock ?? _systemClock() {
    _show(0);
    if (autoTick) {
      _timer = Timer.periodic(Duration(microseconds: 1000000 ~/ pack.fps), (_) => tick());
    }
  }

  static PlaybackClock _systemClock() {
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  static Future<RecordedCamera> load(Recording recording) async {
    final data = await rootBundle.load(recording.asset);
    return RecordedCamera(FramePack.parse(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)),
        recording: recording);
  }

  final FramePack pack;
  final Recording recording;
  final PlaybackClock _now;
  Timer? _timer;
  StreamController<CameraFrame>? _frames;

  /// The frame on show (for the preview).
  final current = ValueNotifier<RecordedFrame?>(null);

  /// Playback position, and whether it is moving.
  final position = ValueNotifier(Duration.zero);
  final playing = ValueNotifier(false);

  Duration _positionAtStart = Duration.zero;
  Duration? _startedAt;
  Uint8List? _bgra;

  Duration get duration => pack.duration;

  @override
  int get uprightRotation => 0;

  /// The recordings are compressed video: blocks re-encoded about once a
  /// second differ by up to ~20 levels (measured on both Live test boards).
  @override
  int get minChange => 20;

  /// A recording can't zoom: its pixels are all there is.
  @override
  double get maxZoom => 1;

  @override
  double get zoom => 1;

  @override
  Future<void> setZoom(double level) async {}

  /// Plays from the start.
  void restart() {
    _positionAtStart = Duration.zero;
    _startedAt = _now();
    playing.value = true;
    tick();
  }

  Duration _position() {
    final started = _startedAt;
    final p = started == null ? _positionAtStart : _positionAtStart + (_now() - started);
    return p < duration ? p : duration;
  }

  /// Moves to the frame for the current position and delivers it. Called
  /// every 1 / fps seconds (by a timer unless the camera was made with
  /// `autoTick: false`).
  @visibleForTesting
  void tick() {
    final p = _position();
    position.value = p;
    var index = p.inMicroseconds * pack.fps ~/ 1000000;
    if (index >= pack.frameCount - 1) {
      index = pack.frameCount - 1;
      if (playing.value) {
        _positionAtStart = duration;
        _startedAt = null;
        playing.value = false;
      }
    }
    if (current.value?.index != index) _show(index);
    final frames = _frames;
    final bgra = _bgra;
    if (frames == null || !frames.hasListener || bgra == null) return;
    frames.add(CameraFrame(
      width: pack.width,
      height: pack.height,
      format: FrameFormat.bgra8888,
      planes: [FramePlane(bytes: bgra, bytesPerRow: pack.width * 4, bytesPerPixel: 4)],
      timestamp: _now(),
    ));
  }

  void _show(int index) {
    final image = img.decodeJpg(pack.jpeg(index));
    if (image == null) return;
    _bgra = image.getBytes(order: img.ChannelOrder.bgra);
    current.value = RecordedFrame(index, image.width, image.height, image.getBytes(order: img.ChannelOrder.rgba));
  }

  @override
  Stream<CameraFrame> frames() => (_frames ??= StreamController<CameraFrame>.broadcast()).stream;

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _frames?.close();
    _frames = null;
  }
}
