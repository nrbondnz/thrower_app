import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/camera_frame.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/camera/recording_analysis_feed.dart';
import 'package:thrower_app/vision/frame_to_rgb.dart';

import 'recorded_camera_test.dart' show greyPack;

void main() {
  const recording = Recording(name: 'Test', description: '', asset: '');
  late Duration now;
  late RecordedCamera camera;
  late RecordingAnalysisFeed feed;
  late List<CameraFrame> analysed;
  late int decodes;

  setUp(() async {
    now = Duration.zero;
    decodes = 0;
    camera = RecordedCamera(greyPack(), recording: recording, clock: () => now, autoTick: false, decoder: decodeFramePureDart);
    feed = RecordingAnalysisFeed(camera, decoder: (jpeg) {
      decodes++;
      return decodeFramePureDart(jpeg);
    });
    analysed = [];
    await pumpEventQueue();
  });
  tearDown(() async {
    await feed.dispose();
    await camera.dispose();
  });

  /// The grey levels (0, 80, 160, 240 for frames 0–3) of the frames analysed.
  List<int> greys() => [for (final f in analysed) (frameToRgb(f)!.red(4, 3) / 80).round() * 80];

  /// Playback jumps straight to [t] (as when the screen skips frames).
  Future<void> playTo(Duration t) async {
    now = t;
    camera.tick();
    await pumpEventQueue();
  }

  test('every frame up to the one shown is analysed, in order, even when the picture skipped them', () async {
    feed.frames().listen(analysed.add);
    camera.restart();
    await playTo(const Duration(milliseconds: 1600)); // Frame 3, straight from 0.
    expect(greys(), [0, 80, 160, 240]);
  });

  test("frames are stamped with their place in the recording, not when they're analysed", () async {
    feed.frames().listen(analysed.add);
    camera.restart();
    await playTo(const Duration(milliseconds: 1600));
    expect([for (final f in analysed) f.timestamp.inMilliseconds], [0, 500, 1000, 1500]);
  });

  test('analysis never runs ahead of the picture', () async {
    feed.frames().listen(analysed.add);
    camera.restart();
    await playTo(const Duration(milliseconds: 600)); // Frame 1.
    expect(greys(), [0, 80]);
    expect(feed.analysed.value, 1);
  });

  test('played again from the start, analysis starts again from the first frame', () async {
    feed.frames().listen(analysed.add);
    camera.restart();
    await playTo(const Duration(milliseconds: 1600));
    analysed.clear();
    now = const Duration(seconds: 5);
    camera.restart();
    await pumpEventQueue();
    await playTo(const Duration(milliseconds: 5600));
    expect(greys(), [0, 80]);
  });

  test('nothing is decoded while nobody listens', () async {
    camera.restart();
    await playTo(const Duration(milliseconds: 1600));
    expect(decodes, 0);
  });
}
