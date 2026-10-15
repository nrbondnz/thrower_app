import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/frame_pack.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/game/quick_draw_watcher.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/frame_to_rgb.dart';
import 'package:thrower_app/vision/tapped_target_locator.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/target_locator.dart';

import 'live_replay_test.dart' show frameOf;

/// Replays the Quick draw clip through the app's own path (`RecordedCamera`
/// → `QuickDrawWatcher`, a crop and a throw watcher per board), with the
/// boards chosen by taps on their centres, and checks each player's throw
/// against the answer key (`docs/thrower/reference/live-camera/
/// quickdraw.json`).
Future<List<QuickDrawThrow?>> replay() async {
  final pack = FramePack.parse(File(quickDrawRecording.asset).readAsBytesSync());
  var now = Duration.zero;
  final camera = RecordedCamera(pack, recording: quickDrawRecording, autoTick: false, clock: () => now, decoder: decodeFramePureDart);
  final model = TargetModel.ikthof();
  final radii = [for (final r in model.rings.take(model.rings.length - 1)) r.outerRadius];
  final first = frameToRgb(frameOf(pack, 0), maxSide: 1920)!;
  // Taps on each board's centre (tapped_target_locator_test.dart), Player 1's first.
  final boards = [
    for (final tap in const [Point2(182.5, 463.4), Point2(592.7, 471.7)])
      switch (locateTargetAt(first, tap, radii)) {
        TargetFound(:final boundaries, :final outer) =>
          TargetCalibration(imageWidth: pack.width, imageHeight: pack.height, boundaries: boundaries, outer: outer),
        TargetNotFound(:final reason) => throw StateError('board at $tap not found: $reason'),
      },
  ];
  final watcher = QuickDrawWatcher(camera, boards, model: model)..start();
  await pumpEventQueue();
  camera.restart();
  // The whole clip, then a second of its last frame.
  for (var i = 0; i < pack.frameCount + 60; i++) {
    now = Duration(microseconds: i * 1000000 ~/ pack.fps);
    camera.tick();
    await pumpEventQueue();
  }
  final throws = watcher.throws.value;
  await watcher.dispose();
  await camera.dispose();
  return throws;
}

void main() {
  final key = jsonDecode(File('docs/thrower/reference/live-camera/quickdraw.json').readAsStringSync()) as Map<String, dynamic>;
  final boards = (key['boards'] as List).cast<Map<String, dynamic>>();
  // Player 1 tapped the left board.
  final expected = [boards.firstWhere((b) => b['id'] == 'left'), boards.firstWhere((b) => b['id'] == 'right')];
  const frame = Duration(microseconds: 1000000 ~/ 60);
  late List<QuickDrawThrow?> throws;

  setUpAll(() async => throws = await replay());

  for (final (player, board) in expected.indexed) {
    group('Player ${player + 1} (${board['id']} board)', () {
      test('the throw is found, as ${board['kind']}', () {
        expect(throws[player], isNotNull, reason: 'no throw found');
        expect(throws[player]!.stuck, board['kind'] == 'stuck');
      });

      test('it reached the board within a frame of the answer key (frame ${board['impactFrame']})', () {
        final impact = throws[player]!.impact;
        final keyed = Duration(microseconds: ((board['impact'] as num) * 1000000).round());
        expect((impact - keyed).abs(), lessThanOrEqualTo(frame),
            reason: 'impact at ${impact.inMilliseconds} ms, answer key ${keyed.inMilliseconds} ms');
      });

      if (board['kind'] == 'stuck') {
        test('it scores ${board['score']}', () => expect(throws[player]!.score, board['score']));
      }
    });
  }

  test('Player 2 reached the board first', () {
    expect(throws[1]!.impact, lessThan(throws[0]!.impact));
  });
}
