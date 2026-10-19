import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/camera_frame.dart';
import 'package:thrower_app/camera/frame_pack.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/game/quick_draw_judge.dart';
import 'package:thrower_app/game/quick_draw_watcher.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/tapped_target_locator.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/target_locator.dart';

import '../camera/cropped_camera_test.dart' show PushCamera;

/// [upright] as a BGRA frame turned a quarter-turn anticlockwise, as an
/// Android camera sends a portrait picture (it needs turning 90° clockwise).
CameraFrame sideways(RgbImage upright, Duration at) {
  final w = upright.width, h = upright.height; // Sideways: h wide, w high.
  final bytes = Uint8List(w * h * 4);
  final p = upright.pixels;
  for (var uy = 0; uy < h; uy++) {
    for (var ux = 0; ux < w; ux++) {
      final i = ((w - 1 - ux) * h + uy) * 4, j = (uy * w + ux) * 3;
      bytes[i] = p[j + 2];
      bytes[i + 1] = p[j + 1];
      bytes[i + 2] = p[j];
      bytes[i + 3] = 255;
    }
  }
  return CameraFrame(
    width: h,
    height: w,
    format: FrameFormat.bgra8888,
    planes: [FramePlane(bytes: bytes, bytesPerRow: h * 4, bytesPerPixel: 4)],
    timestamp: at,
  );
}

/// The Quick draw clip through the **live** path: a camera whose frames
/// arrive sideways (Android), every board's crop queued (`QueuedCamera`), the
/// boards chosen by taps on the upright picture. All frames arrive at once,
/// as from a phone far slower than the camera; analysis must still see every
/// one, in order, and give the answer key's throws.
void main() {
  final key = jsonDecode(File('docs/thrower/reference/live-camera/quickdraw.json').readAsStringSync()) as Map<String, dynamic>;
  final boards = (key['boards'] as List).cast<Map<String, dynamic>>();
  final expected = [boards.firstWhere((b) => b['id'] == 'left'), boards.firstWhere((b) => b['id'] == 'right')];
  const frame = Duration(microseconds: 1000000 ~/ 60);
  late List<QuickDrawThrow?> throws;

  setUpAll(() async {
    final pack = FramePack.parse(File(quickDrawRecording.asset).readAsBytesSync());
    final model = TargetModel.katta();
    final radii = [for (final r in model.rings.take(model.rings.length - 1)) r.outerRadius];
    final first = decodeToRgb(pack.jpeg(0))!;
    final calibrations = [
      for (final tap in const [Point2(182.5, 463.4), Point2(592.7, 471.7)])
        switch (locateTargetAt(first, tap, radii)) {
          TargetFound(:final boundaries, :final outer) =>
            TargetCalibration(imageWidth: first.width, imageHeight: first.height, boundaries: boundaries, outer: outer),
          TargetNotFound(:final reason) => throw StateError('board at $tap not found: $reason'),
        },
    ];
    final camera = PushCamera(uprightRotation: 90);
    final watcher = QuickDrawWatcher(camera, calibrations, model: model, queue: true)..start();
    // From a second before go (frame 108) to well after the throws, all at once.
    for (var i = 108; i < 330; i++) {
      camera.controller.add(sideways(decodeToRgb(pack.jpeg(i))!, Duration(microseconds: i * 1000000 ~/ 60)));
    }
    // Let the frames reach the queues, then wait for analysis to work through them.
    await pumpEventQueue();
    while (watcher.queues.any((q) => q.waiting.value > 0)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // The last frames' entry search runs in the background.
    await Future<void>.delayed(const Duration(seconds: 2));
    throws = watcher.throws.value;
    await watcher.dispose();
  });

  for (final (player, board) in expected.indexed) {
    test('Player ${player + 1} (${board['id']}): ${board['kind']}, within a frame of the answer key', () {
      final t = throws[player];
      expect(t, isNotNull, reason: 'no throw found');
      expect(t!.stuck, board['kind'] == 'stuck');
      final keyed = Duration(microseconds: ((board['impact'] as num) * 1000000).round());
      expect((t.impact - keyed).abs(), lessThanOrEqualTo(frame), reason: 'impact ${t.impact.inMilliseconds} ms, key ${keyed.inMilliseconds} ms');
      if (board['kind'] == 'stuck') expect(t.score, board['score']);
    });
  }

  test('no frame was dropped', () {
    expect(throws.whereType<QuickDrawThrow>(), hasLength(2));
  });

  test("judged from go (2.8 s, on the frames' clock), Player 2 (Mark) wins, about 0.82 s after go", () {
    final v = judgeQuickDraw(throws, quickDrawRecording.go!);
    expect(v.winner, 1);
    expect(v.players[1].afterGo!.inMilliseconds, closeTo(817, 17));
  });
}
