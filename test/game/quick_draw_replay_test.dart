import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/frame_pack.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/camera/recording_analysis_feed.dart';
import 'package:thrower_app/game/quick_draw_judge.dart';
import 'package:thrower_app/game/quick_draw_watcher.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/frame_to_rgb.dart';
import 'package:thrower_app/vision/tapped_target_locator.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/target_locator.dart';

import 'live_replay_test.dart' show frameOf;

/// Replays the Quick draw clip through the app's own path (`RecordedCamera`
/// → `RecordingAnalysisFeed` → `QuickDrawWatcher`, a crop and a throw
/// watcher per board), with the boards chosen by taps on their centres, and
/// checks each player's throw against the answer key
/// (`docs/thrower/reference/live-camera/quickdraw.json`).
///
/// Playback moves on [step] frames per tick: more than 1 is a phone that
/// can't keep up (the screen skips frames); analysis must still see them all.
Future<List<QuickDrawThrow?>> replay({int step = 1}) async {
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
  // As the app does: from a second before go.
  final feed = RecordingAnalysisFeed(camera, from: quickDrawRecording.go! - quickDrawLeadIn);
  final watcher = QuickDrawWatcher(feed, boards, model: model)..start();
  await pumpEventQueue();
  camera.restart();
  // The whole clip, then a second of its last frame.
  for (var i = 0; i < pack.frameCount + 60; i += step) {
    now = Duration(microseconds: i * 1000000 ~/ pack.fps);
    camera.tick();
    await pumpEventQueue();
  }
  // Let analysis catch up with the picture.
  while (feed.analysed.value < pack.frameCount - 1) {
    await pumpEventQueue();
  }
  await pumpEventQueue();
  final throws = watcher.throws.value;
  await watcher.dispose();
  await feed.dispose();
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

  test('the verdict: Player 2 (Mark) wins, stuck 5, about 0.82 s after go; Player 1 bounced', () {
    final v = judgeQuickDraw(throws, quickDrawRecording.go!);
    expect(v.winner, 1);
    expect(v.players[0].result, QuickDrawResult.bounced);
    expect(v.players[1].afterGo!.inMilliseconds, closeTo(817, 17));
  });

  test('with playback skipping 2 of every 3 frames, analysis still sees them all: the same throws, the same frames', () async {
    final skipped = await replay(step: 3);
    for (var p = 0; p < 2; p++) {
      expect(skipped[p]?.stuck, throws[p]!.stuck, reason: 'Player ${p + 1}');
      expect(skipped[p]!.impact, throws[p]!.impact, reason: 'Player ${p + 1}');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
