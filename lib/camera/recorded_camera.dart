import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'camera_frame.dart';
import 'frame_pack.dart';
import 'recording_sound.dart';
import 'target_camera.dart';

/// A recording the Live test can play, bundled with the app.
class Recording {
  const Recording({required this.name, required this.description, required this.asset, this.audio, this.go});

  final String name;
  final String description;

  /// A [FramePack] asset.
  final String asset;

  /// Its sound track (an audio asset the same length, starting with the
  /// first frame), or null for none.
  final String? audio;

  /// Quick draw: when the countdown in the recording says "go", from its
  /// start. Null for recordings without one.
  final Duration? go;
}

/// The two real boards from Nigel's video, cropped one per board from the
/// original (2026-10-12; 322 × 322 px, boards ~245 px across):
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

/// Quick draw: both boards in the full picture (720 × 1280, 60 fps), from
/// the original video at 158.5–166 s: a quiet countdown ("go" at 2.8 s), then
/// both knives at about 3.6 s. Answer key:
/// `docs/thrower/reference/live-camera/quickdraw.json` ("go" at 161.3 s in
/// the original, by Nigel's ear).
const quickDrawRecording = Recording(
  name: 'Quick draw',
  description: 'Two throwers, a countdown, both boards',
  asset: 'assets/live/quickdraw.tfrm',
  audio: 'assets/live/quickdraw.m4a',
  go: Duration(milliseconds: 2800),
);

/// The frame on show, for the preview.
class RecordedFrame {
  const RecordedFrame(this.index, this.image);

  final int index;

  /// Owned by the camera and disposed when the next frame replaces it: a
  /// widget that keeps it must take its own `clone()`. Null when the decoder
  /// makes no image (tests).
  final ui.Image? image;
}

/// One recording frame, decoded: BGRA bytes for throw detection (like a live
/// camera frame) and, optionally, an image for the preview.
class DecodedFrame {
  const DecodedFrame(this.width, this.height, this.bgra, [this.image]);

  final int width;
  final int height;
  final Uint8List bgra;
  final ui.Image? image;
}

/// Decodes one frame's JPEG.
typedef FrameDecoder = Future<DecodedFrame?> Function(Uint8List jpeg);

/// The app's decoder: Flutter's native image codec, which decodes off the UI
/// thread. The pure-Dart decoder took 15–27 ms per 322 px frame on a PC, all
/// on the UI thread, which made playback jump and freeze on a budget Android
/// (Known Issues → Live Test Playback Jumps and Freezes).
Future<DecodedFrame?> decodeFrameNatively(Uint8List jpeg) async {
  final codec = await ui.instantiateImageCodec(jpeg);
  final ui.Image image;
  try {
    image = (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (rgba == null) {
    image.dispose();
    return null;
  }
  return DecodedFrame(image.width, image.height, rgbaToBgra(rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes)), image);
}

/// Pure-Dart decoding (the `image` package), with no preview image: for tests,
/// where it is synchronous underneath and needs no engine.
Future<DecodedFrame?> decodeFramePureDart(Uint8List jpeg) async {
  final image = img.decodeJpg(jpeg);
  if (image == null) return null;
  return DecodedFrame(image.width, image.height, image.getBytes(order: img.ChannelOrder.bgra));
}

/// Swaps red and blue in place, four bytes at a time, and returns [rgba].
@visibleForTesting
Uint8List rgbaToBgra(Uint8List rgba) {
  final words = rgba.buffer.asUint32List(rgba.offsetInBytes, rgba.lengthInBytes ~/ 4);
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    // Little-endian: bytes R, G, B, A are bits 0–7, 8–15, 16–23, 24–31.
    words[i] = (w & 0xFF00FF00) | ((w & 0xFF) << 16) | ((w >> 16) & 0xFF);
  }
  return rgba;
}

/// Where playback time comes from; tests replace it.
typedef PlaybackClock = Duration Function();

/// Plays a [FramePack] as if it were a camera: like the live camera it runs
/// all the time, delivering a frame (BGRA, already upright) every
/// 1 / fps seconds to whoever listens, stamped with a monotonic clock.
///
/// It opens **paused on the first frame** (so the board can be calibrated
/// before anything happens); [restart] plays from the start, it stops on
/// the last frame, and [rewind] goes back to waiting on the first. Frames are decoded only when the position moves on, one at
/// a time and asynchronously: if decoding can't keep up, frames in between are
/// skipped (as a slow live camera drops them) rather than holding up the UI.
class RecordedCamera implements TargetCamera {
  RecordedCamera(
    this.pack, {
    required this.recording,
    PlaybackClock? clock,
    bool autoTick = true,
    this.decoder = decodeFrameNatively,
    this.sound,
  }) : _now = clock ?? _systemClock() {
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
    final audio = recording.audio;
    return RecordedCamera(FramePack.parse(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes)),
        recording: recording, sound: audio == null ? null : AssetRecordingSound(audio));
  }

  final FramePack pack;
  final Recording recording;
  final PlaybackClock _now;

  /// Turns each frame's JPEG into pixels ([decodeFrameNatively] in the app).
  final FrameDecoder decoder;

  /// The recording's sound, started and stopped with playback.
  final RecordingSound? sound;
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

  /// The frame being decoded, and the newest one wanted when it's done.
  int? _decoding;
  int? _wanted;
  var _disposed = false;

  Duration get duration => pack.duration;

  @override
  int get uprightRotation => 0;

  /// The recordings are compressed (video, then JPEG frames), which adds
  /// block noise of up to ~20 levels that a live camera doesn't have. At the
  /// live camera's 12, the full-resolution recordings (2026-10-12) gave false
  /// bounce-outs on board 1 (69.4 s, 129.5 s); the 140 px copy did too.
  @override
  int get minChange => 20;

  /// A recording can't zoom: its pixels are all there is.
  @override
  double get maxZoom => 1;

  @override
  Duration get now => _now();

  @override
  double get zoom => 1;

  @override
  Future<void> setZoom(double level) async {}

  /// Plays from the start.
  void restart() {
    _delivered = null;
    _positionAtStart = Duration.zero;
    _startedAt = _now();
    playing.value = true;
    _withSound((s) => s.playFromStart());
    tick();
  }

  /// Stops and waits on the first frame again, as when it opened: the Play
  /// screen calls this on leaving, so calibrating afterwards sees the board
  /// before any throws (not the frame playback had reached).
  void rewind() {
    if (_disposed) return;
    _delivered = null;
    _positionAtStart = Duration.zero;
    _startedAt = null;
    playing.value = false;
    _withSound((s) => s.stop());
    tick();
  }

  /// Sound is a nice-to-have: if it fails, the frames play on regardless.
  void _withSound(Future<void> Function(RecordingSound sound) action) {
    final s = sound;
    if (s == null) return;
    action(s).catchError((Object e, StackTrace st) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st, library: 'recorded camera'));
    });
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
    // The nearest frame, not the one before: ticks come every 1 / fps seconds
    // give or take timer jitter, and rounding down turned a tick a hair early
    // into the previous frame again, then a skip (0, 0, 1, 3, 3, 4, …).
    var index = (p.inMicroseconds * pack.fps + 500000) ~/ 1000000;
    if (index >= pack.frameCount - 1) {
      index = pack.frameCount - 1;
      if (playing.value) {
        _positionAtStart = duration;
        _startedAt = null;
        playing.value = false;
      }
    }
    _show(index);
    // Playing, each frame is delivered once, when it has been decoded
    // ([_decoded]), or now if it already was (frame 0 on restart). Paused
    // (before Play, or after the end), the camera keeps seeing the same still
    // picture.
    if (!playing.value || (current.value?.index == index && _delivered != index)) _deliver();
  }

  /// The frame last delivered while playing (null since [restart]).
  int? _delivered;

  /// Sends the frame on show to whoever listens, stamped now.
  ///
  /// While playing this happens once per decoded frame, never on every tick:
  /// re-sending the last frame while the next is still decoding fed throw
  /// detection repeats (0, 0, 1, 3, 3, 4, …), which look like the board
  /// standing still mid-throw (2026-10-13).
  void _deliver() {
    final frames = _frames;
    final bgra = _bgra;
    if (frames == null || !frames.hasListener || bgra == null) return;
    _delivered = current.value?.index;
    frames.add(CameraFrame(
      width: pack.width,
      height: pack.height,
      format: FrameFormat.bgra8888,
      planes: [FramePlane(bytes: bgra, bytesPerRow: pack.width * 4, bytesPerPixel: 4)],
      timestamp: _now(),
    ));
  }

  /// Asks for frame [index]; it is decoded now, or straight after the frame
  /// already being decoded (skipping any asked for in between).
  void _show(int index) {
    if (_decoding != null) {
      if (_decoding != index) _wanted = index;
      return;
    }
    if (current.value?.index == index) return;
    _decoding = index;
    _wanted = null;
    decoder(pack.jpeg(index)).then(
      (decoded) => _decoded(index, decoded),
      onError: (Object e, StackTrace s) {
        _decoding = null;
        FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s, library: 'recorded camera'));
      },
    );
  }

  void _decoded(int index, DecodedFrame? decoded) {
    _decoding = null;
    if (_disposed) {
      decoded?.image?.dispose();
      return;
    }
    if (decoded != null) {
      _bgra = decoded.bgra;
      final previous = current.value?.image;
      current.value = RecordedFrame(index, decoded.image);
      previous?.dispose();
      if (playing.value) _deliver();
    }
    final next = _wanted;
    if (next != null) _show(next);
  }

  @override
  Stream<CameraFrame> frames() => (_frames ??= StreamController<CameraFrame>.broadcast()).stream;

  @override
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    current.value?.image?.dispose();
    await sound?.dispose();
    await _frames?.close();
    _frames = null;
  }
}
