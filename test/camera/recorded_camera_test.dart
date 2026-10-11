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

  setUp(() {
    now = Duration.zero;
    camera = RecordedCamera(greyPack(), recording: recording, clock: () => now, autoTick: false);
    delivered = [];
    camera.frames().listen(delivered.add);
  });
  tearDown(() => camera.dispose());

  int greyOf(CameraFrame f) => frameToRgb(f, rotation: 0)!.red(4, 3);

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
    now = const Duration(milliseconds: 600); // 0.6 s at 2 fps: frame 1
    camera.tick();
    now = const Duration(milliseconds: 1100); // frame 2
    camera.tick();
    await pumpEventQueue();
    expect(delivered.map(greyOf), [closeTo(0, 3), closeTo(80, 3), closeTo(160, 3)]);
    expect(camera.current.value!.index, 2);
  });

  test('stops on the last frame at the end', () async {
    camera.restart();
    now = const Duration(seconds: 10);
    camera.tick();
    expect(camera.playing.value, isFalse);
    expect(camera.current.value!.index, 3);
    expect(camera.position.value, camera.duration);
    now = const Duration(seconds: 11);
    camera.tick();
    expect(camera.current.value!.index, 3);
  });

  test('restart after the end plays from the start again', () {
    camera.restart();
    now = const Duration(seconds: 10);
    camera.tick();
    camera.restart();
    camera.tick();
    expect(camera.playing.value, isTrue);
    expect(camera.current.value!.index, 0);
  });
}
