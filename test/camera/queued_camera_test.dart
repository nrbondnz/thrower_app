import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/camera_frame.dart';
import 'package:thrower_app/camera/cropped_camera.dart';
import 'package:thrower_app/camera/queued_camera.dart';

import 'cropped_camera_test.dart' show PushCamera;

/// A 4 × 2 BGRA frame stamped [ms], whose first byte is [n].
CameraFrame frame(int n, int ms) => CameraFrame(
      width: 4,
      height: 2,
      format: FrameFormat.bgra8888,
      planes: [FramePlane(bytes: Uint8List(32)..[0] = n, bytesPerRow: 16, bytesPerPixel: 4)],
      timestamp: Duration(milliseconds: ms),
    );

void main() {
  late PushCamera source;
  late QueuedCamera queued;
  late List<CameraFrame> got;

  setUp(() {
    source = PushCamera(uprightRotation: 90);
    queued = QueuedCamera(source);
    got = [];
  });
  tearDown(() => queued.dispose());

  test('frames arriving faster than they are taken are all handed on, in order', () async {
    queued.frames().listen(got.add);
    for (var i = 0; i < 20; i++) {
      source.controller.add(frame(i, i * 16));
    }
    await pumpEventQueue(times: 100);
    expect([for (final f in got) f.planes.first.bytes[0]], List.generate(20, (i) => i));
    expect([for (final f in got) f.timestamp.inMilliseconds], List.generate(20, (i) => i * 16));
  });

  test('while frames wait, it says how many and how far behind', () async {
    queued.frames().listen(got.add);
    for (var i = 0; i < 5; i++) {
      source.controller.add(frame(i, i * 16));
    }
    await pumpEventQueue(times: 1);
    expect(queued.waiting.value, greaterThan(0));
    expect(queued.behind, greaterThan(Duration.zero));
    await pumpEventQueue(times: 100);
    expect((queued.waiting.value, queued.behind), (0, Duration.zero));
  });

  test('frames are kept as compact copies, not views into the whole frame', () async {
    final big = CameraFrame(
      width: 2,
      height: 2,
      format: FrameFormat.bgra8888,
      // A 2 × 2 crop of a 100-pixel-wide frame: a view into 800 bytes a row.
      planes: [FramePlane(bytes: Uint8List(800 * 2), bytesPerRow: 400, bytesPerPixel: 4)],
      timestamp: Duration.zero,
    );
    queued.frames().listen(got.add);
    source.controller.add(big);
    await pumpEventQueue();
    expect(got.single.planes.first.bytes.length, 16);
  });

  test('past its size limit the oldest frames are dropped and counted', () async {
    final small = QueuedCamera(source, maxBytes: 3 * 32); // Three 4 × 2 BGRA frames.
    addTearDown(small.dispose);
    small.frames().listen(got.add);
    for (var i = 0; i < 6; i++) {
      source.controller.add(frame(i, i));
    }
    await pumpEventQueue(times: 100);
    expect(small.dropped, greaterThan(0));
    expect(got.last.planes.first.bytes[0], 5);
  });

  test('reports the source\'s rotation (its frames are still in the sensor\'s layout)', () {
    expect(queued.uprightRotation, 90);
    expect(compactFrame(frame(1, 0)).width, 4);
  });

  test('after stopTaking, new frames are ignored but those waiting are still handed on', () async {
    queued.frames().listen(got.add);
    for (var i = 0; i < 3; i++) {
      source.controller.add(frame(i, i));
    }
    await pumpEventQueue(times: 1);
    await queued.stopTaking();
    source.controller.add(frame(9, 9));
    await pumpEventQueue(times: 100);
    expect([for (final f in got) f.planes.first.bytes[0]], [0, 1, 2]);
  });

  test("the clock is the source's", () {
    source.now = const Duration(seconds: 3);
    expect(queued.now, const Duration(seconds: 3));
  });
}
