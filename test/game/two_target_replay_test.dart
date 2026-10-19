import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/frame_pack.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/game/play_boards_watcher.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/tapped_target_locator.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/target_locator.dart';

/// Players-and-targets story, Task 3: the Quick draw recording (both boards)
/// played through two-target Play's own path: the recorded camera → a
/// `ThrowWatcher` per board on its crop (`PlayBoardsWatcher`, at Play's usual
/// pace, from the clip's first frame) → `GameNotifier` in
/// `PlayMode.twoTargets`. The answer key (`quickdraw.json`): the left board
/// (Player 1) bounced out; the right board (Player 2, Mark) stuck a 5. Each
/// throw must be scored for its own board's player, and nothing else taken
/// for a throw.
void main() {
  final key = jsonDecode(File('docs/thrower/reference/live-camera/quickdraw.json').readAsStringSync()) as Map<String, dynamic>;
  final boards = (key['boards'] as List).cast<Map<String, dynamic>>();
  final expected = [boards.firstWhere((b) => b['id'] == 'left'), boards.firstWhere((b) => b['id'] == 'right')];
  late Match match;

  setUpAll(() async {
    final pack = FramePack.parse(File(quickDrawRecording.asset).readAsBytesSync());
    var now = Duration.zero;
    final camera = RecordedCamera(pack, recording: quickDrawRecording, autoTick: false, clock: () => now, decoder: decodeFramePureDart);
    final model = TargetModel.katta();
    final radii = [for (final r in model.rings.take(model.rings.length - 1)) r.outerRadius];
    final first = decodeToRgb(pack.jpeg(0))!;
    // Each board as found from a tap on its centre (the same taps as the
    // Quick draw tests), Player 1 (left) first.
    final calibrations = [
      for (final tap in const [Point2(182.5, 463.4), Point2(592.7, 471.7)])
        switch (locateTargetAt(first, tap, radii)) {
          TargetFound(:final boundaries, :final outer) =>
            TargetCalibration(imageWidth: first.width, imageHeight: first.height, boundaries: boundaries, outer: outer),
          TargetNotFound(:final reason) => throw StateError('board at $tap not found: $reason'),
        },
    ];
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(playModeProvider.notifier).choose(PlayMode.twoTargets);
    final game = container.read(gameProvider.notifier);

    final watcher = PlayBoardsWatcher(camera, calibrations)..start();
    final events = watcher.events.listen((e) => game.onEvent(e.event, e.calibration, board: e.board));
    await pumpEventQueue();
    camera.restart();
    // The whole clip, then a second of its last frame.
    for (var i = 0; i < pack.frameCount + 60; i++) {
      now = Duration(microseconds: i * 1000000 ~/ pack.fps);
      camera.tick();
      await pumpEventQueue();
    }
    // A stuck knife's entry search runs in the background.
    await Future<void>.delayed(const Duration(seconds: 2));
    await pumpEventQueue();
    await events.cancel();
    await watcher.dispose();
    await camera.dispose();
    match = container.read(gameProvider);
  });

  String describe(GameSession g) =>
      [for (final r in g.rounds) [for (final t in r.throws) '${t.result.name} ${t.score}'].join(', ')].join(' | ');

  for (final (player, board) in expected.indexed) {
    test("Player ${player + 1} (${board['id']} board): one throw, ${board['kind']}, scoring ${board['score']}", () {
      final throws = [for (final r in match.players[player].rounds) ...r.throws];
      expect(throws, hasLength(1), reason: 'Player ${player + 1}: ${describe(match.players[player])}');
      expect(throws.single.result, board['kind'] == 'stuck' ? ThrowResult.stuck : ThrowResult.bounceOut);
      expect(throws.single.score, board['score']);
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
