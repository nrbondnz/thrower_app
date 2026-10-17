import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/camera_frame.dart';
import 'package:thrower_app/game/throw_watcher.dart';
import 'package:thrower_app/vision/luma_image.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/throw_classifier.dart';

import '../camera/cropped_camera_test.dart' show PushCamera;
import '../vision/motion_detector_test.dart' show Fixture;

/// Score corrections story, Task 2: watching pauses while a score popup is
/// open, so a hand at the phone isn't taken for a throw.

/// [luma] as a grey BGRA camera frame at [time].
CameraFrame frameOf(LumaImage luma, Duration time) {
  final bytes = Uint8List(luma.width * luma.height * 4);
  for (var i = 0; i < luma.pixels.length; i++) {
    final v = luma.pixels[i];
    bytes[i * 4] = bytes[i * 4 + 1] = bytes[i * 4 + 2] = v;
    bytes[i * 4 + 3] = 255;
  }
  return CameraFrame(
    width: luma.width,
    height: luma.height,
    format: FrameFormat.bgra8888,
    planes: [FramePlane(bytes: bytes, bytesPerRow: luma.width * 4, bytesPerPixel: 4)],
    timestamp: time,
  );
}

void main() {
  final bounce = Fixture('throw-bounce-out');

  /// Plays the bounce-out sequence through a watcher, pausing over the
  /// frames [pausedFrom]–[pausedTo] if given; returns what it reported.
  Future<List<ThrowOutcomeKind>> play({int? pausedFrom, int? pausedTo}) async {
    final camera = PushCamera();
    final watcher = ThrowWatcher(camera, bounce.calibration, interval: Duration.zero)..start();
    final kinds = <ThrowOutcomeKind>[];
    final sub = watcher.events.listen((e) => kinds.add(e.outcome.kind));
    for (var i = 0; i < bounce.frames.length; i++) {
      if (i == pausedFrom) watcher.pause();
      if (i == pausedTo) watcher.resume();
      camera.controller.add(frameOf(bounce.frames[i], Duration(microseconds: (i * 1e6 / bounce.fps).round())));
      await pumpEventQueue();
    }
    await sub.cancel();
    await watcher.dispose();
    return kinds;
  }

  test('unpaused, the rendered bounce-out is reported', () async {
    expect(await play(), contains(ThrowOutcomeKind.bounceOut));
  });

  test('paused over the throw, nothing is reported, after resuming either', () async {
    expect(await play(pausedFrom: bounce.firstMoving - 2, pausedTo: bounce.lastMoving + 2), isEmpty);
  });

  test('paused mid-throw, the rest of it is not taken for a throw on resuming', () async {
    final middle = (bounce.firstMoving + bounce.lastMoving) ~/ 2;
    expect(await play(pausedFrom: middle, pausedTo: bounce.lastMoving + 2), isEmpty);
  });

  test('resume says ready again', () async {
    final camera = PushCamera();
    final watcher = ThrowWatcher(camera, bounce.calibration)..start();
    watcher.pause();
    watcher.state.value = WatchState.motion;
    watcher.resume();
    expect(watcher.state.value, WatchState.watching);
    await watcher.dispose();
  });
}
