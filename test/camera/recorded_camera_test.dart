import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:thrower_app/camera/camera_frame.dart';
import 'package:thrower_app/camera/frame_pack.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/vision/frame_to_rgb.dart';

/// A 4-frame, 2 fps recording whose frames are solid grey levels 0, 80, 160, 240.
FramePack greyPack() => FramePack.parse(FramePack.build(
      width: 8,
      height: 6,
      fps: 2,
      jpegs: [
        for (final v in [0, 80, 160, 240])
          Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 6)..clear(img.ColorRgb8(v, v, v)), quality: 100)),
      ],
    ));

void main() {
  late Duration now;
  late RecordedCamera camera;
  late List<CameraFrame> delivered;

  const recording = Recording(name: 'Test', description: '', asset: '');

  setUp(() async {
    now = Duration.zero;
    camera = RecordedCamera(greyPack(), recording: recording, clock: () => now, autoTick: false, decoder: decodeFramePureDart);
    delivered = [];
    camera.frames().listen(delivered.add);
    await pumpEventQueue(); // The first frame is decoded.
  });
  tearDown(() => camera.dispose());

  int greyOf(CameraFrame f) => frameToRgb(f, rotation: 0)!.red(4, 3);

  /// Moves the clock to [t], lets the frame for it decode, then ticks again
  /// so it's delivered.
  Future<void> step(Duration t) async {
    now = t;
    camera.tick();
    await pumpEventQueue();
    camera.tick();
    await pumpEventQueue();
  }

  /// Grey levels delivered, with repeats (the same frame on several ticks) removed.
  List<int> distinctGreys() {
    final out = <int>[];
    for (final g in delivered.map(greyOf)) {
      if (out.isEmpty || (out.last - g).abs() > 3) out.add(g);
    }
    return out;
  }

  test('opens paused on the first frame, and keeps delivering it like a camera', () async {
    camera.tick();
    now = const Duration(seconds: 5);
    camera.tick();
    await pumpEventQueue();
    expect(delivered, hasLength(2));
    expect(delivered.map(greyOf), everyElement(closeTo(0, 3)));
    expect(camera.playing.value, isFalse);
  });

  test('delivers upright BGRA frames of the recording\'s size, stamped with the camera clock', () async {
    now = const Duration(milliseconds: 1234);
    camera.tick();
    await pumpEventQueue();
    final f = delivered.single;
    expect((f.width, f.height, f.format), (8, 6, FrameFormat.bgra8888));
    expect(f.timestamp, const Duration(milliseconds: 1234));
    expect(camera.uprightRotation, 0);
  });

  test("can't zoom: its pixels are all there is", () async {
    await camera.setZoom(3);
    expect((camera.maxZoom, camera.zoom), (1, 1));
  });

  test('restart plays through the frames at the recording\'s rate', () async {
    camera.restart();
    await step(const Duration(milliseconds: 600)); // 0.6 s at 2 fps: frame 1
    await step(const Duration(milliseconds: 1100)); // frame 2
    expect(distinctGreys(), [closeTo(0, 3), closeTo(80, 3), closeTo(160, 3)]);
    expect(camera.current.value!.index, 2);
  });

  test('while playing, each frame is delivered exactly once, in order, however often it ticks', () async {
    camera.restart();
    await pumpEventQueue();
    // Two ticks per frame, the second a hair early for the next frame (timer
    // jitter): rounding down used to repeat a frame and then skip one.
    // (Short of the last frame: after the end it keeps showing a still.)
    for (final ms in [480, 500, 990, 1000]) {
      now = Duration(milliseconds: ms);
      camera.tick();
      await pumpEventQueue();
    }
    expect(delivered.map(greyOf), [closeTo(0, 3), closeTo(80, 3), closeTo(160, 3)]);
  });

  test('stops on the last frame at the end', () async {
    camera.restart();
    await step(const Duration(seconds: 10));
    expect(camera.playing.value, isFalse);
    expect(camera.current.value!.index, 3);
    expect(camera.position.value, camera.duration);
    await step(const Duration(seconds: 11));
    expect(camera.current.value!.index, 3);
  });

  test('restart after the end plays from the start again', () async {
    camera.restart();
    await step(const Duration(seconds: 10));
    camera.restart();
    await step(const Duration(seconds: 10)); // The clock restarted at 10 s.
    expect(camera.playing.value, isTrue);
    expect(camera.current.value!.index, 0);
  });

  test('when decoding falls behind, it skips to the newest frame rather than queueing', () async {
    final requests = <Completer<DecodedFrame?>>[];
    final decodedGreys = <int>[];
    final slow = RecordedCamera(greyPack(), recording: recording, clock: () => now, autoTick: false, decoder: (jpeg) {
      final c = Completer<DecodedFrame?>();
      requests.add(c);
      return c.future.then((d) {
        if (d != null) decodedGreys.add(d.bgra[2]); // Red of the first pixel.
        return d;
      });
    });
    addTearDown(slow.dispose);
    Future<void> finish(int i) async {
      requests[i].complete(await decodeFramePureDart(greyPack().jpeg(i == 0 ? 0 : 3)));
      await pumpEventQueue();
    }

    now = Duration.zero;
    await finish(0); // Frame 0, asked for on opening.
    slow.restart();
    now = const Duration(milliseconds: 600);
    slow.tick(); // Asks for frame 1: decoding starts.
    now = const Duration(milliseconds: 1100);
    slow.tick(); // Frame 2 wanted while 1 is still decoding.
    now = const Duration(milliseconds: 1600);
    slow.tick(); // Frame 3 wanted: replaces 2.
    expect(requests, hasLength(2), reason: 'one decode at a time');
    requests[1].complete(await decodeFramePureDart(greyPack().jpeg(1)));
    await pumpEventQueue();
    expect(requests, hasLength(3), reason: 'the newest wanted frame is decoded next');
    await finish(2);
    expect(slow.current.value!.index, 3, reason: 'frame 2 was skipped');
  });

  testWidgets('the native decoder decodes a frame to BGRA and a preview image', (tester) async {
    final pack = FramePack.parse(FramePack.build(width: 8, height: 6, fps: 2, jpegs: [
      Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 6)..clear(img.ColorRgb8(200, 100, 20)), quality: 100)),
    ]));
    final decoded = (await tester.runAsync(() => decodeFrameNatively(pack.jpeg(0))))!;
    addTearDown(() => decoded.image?.dispose());
    expect((decoded.width, decoded.height), (8, 6));
    expect(decoded.bgra.sublist(0, 4), [closeTo(20, 4), closeTo(100, 4), closeTo(200, 4), 255]);
    expect((decoded.image?.width, decoded.image?.height), (8, 6));
  });

  test('rgbaToBgra swaps red and blue, keeping green and alpha', () {
    final bytes = Uint8List.fromList([10, 20, 30, 40, 1, 2, 3, 4]);
    expect(rgbaToBgra(bytes), [30, 20, 10, 40, 3, 2, 1, 4]);
  });
}
