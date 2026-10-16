import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/camera/target_camera.dart';
import 'package:thrower_app/game/throw_watcher.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/ui/live_test_screen.dart';
import 'package:thrower_app/ui/play_screen.dart';
import 'package:thrower_app/ui/play_setup_screen.dart';
import 'package:thrower_app/ui/round_marks.dart';
import 'package:thrower_app/ui/two_target_play_screen.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/entry_point.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/tapped_target_locator.dart';
import 'package:thrower_app/vision/target_locator.dart';
import 'package:thrower_app/vision/throw_classifier.dart';

import '../camera/recorded_camera_test.dart' show greyPack;
import '../game/quick_draw_targets_test.dart' show boardAtCentre;
import '../scoring/match_test.dart' show p;

/// A recorded camera that remembers its zoom, as a live camera would.
class ZoomingCamera extends RecordedCamera {
  ZoomingCamera()
      : super(greyPack(), recording: const Recording(name: 'Test', description: '', asset: ''),
            autoTick: false, clock: () => Duration.zero, decoder: decodeFramePureDart);

  var _zoom = 2.0;

  @override
  double get zoom => _zoom;

  @override
  Future<void> setZoom(double level) async => _zoom = level;
}

void main() {
  late ProviderContainer container;
  late ZoomingCamera camera;

  Future<TappedTargetsResult> fakeLocate(_, Point2 tap) async {
    final b = boardAtCentre(tap.x * 8, tap.y * 6);
    return TappedTargetsResult([TargetFound(boundaries: b.boundaries, outer: b.outer, confidence: 0.8, boundaryPoints: const {})], 8, 6);
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    camera = ZoomingCamera();
    addTearDown(camera.dispose);
    container = ProviderContainer(overrides: [
      cameraProvider.overrideWith((ref) async => camera as TargetCamera),
      tapLocatorProvider.overrideWithValue(fakeLocate),
    ]);
    addTearDown(container.dispose);
    container.read(playModeProvider.notifier).choose(PlayMode.twoTargets);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(home: screen)));
    await tester.pump();
    await tester.pump();
  }

  String instruction(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('quickDrawInstruction'))).data!;

  Future<void> tapPicture(WidgetTester tester, double fx, double fy) async {
    final area = tester.getRect(find.byKey(const Key('quickDrawBoardTap')));
    await tester.tapAt(Offset(area.left + area.width * fx, area.top + area.height * fy));
    await tester.pump();
    await tester.pump();
  }

  Future<void> chooseAndLock(WidgetTester tester) async {
    await tapPicture(tester, 0.25, 0.5);
    await tapPicture(tester, 0.75, 0.5);
    await tester.tap(find.byKey(const Key('playLockBoards')));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('asks for Player 1\'s board, then Player 2\'s, then to lock them', (tester) async {
    await pumpScreen(tester, const TwoTargetPlayScreen());
    expect(instruction(tester), "Tap the centre of Player 1's board.");
    await tapPicture(tester, 0.25, 0.5);
    expect(instruction(tester), "Tap the centre of Player 2's board.");
    await tapPicture(tester, 0.75, 0.5);
    expect(instruction(tester), 'Both boards found: lock them, or choose them again.');
    expect(container.read(playTargetsProvider).boards.map((b) => b.outer.cx), [2, 6]);
    expect(container.read(quickDrawTargetsProvider).boards, isEmpty, reason: "Quick draw's boards are its own");
  });

  testWidgets('locked: both players\' scores, and each board\'s watch state', (tester) async {
    await pumpScreen(tester, const TwoTargetPlayScreen());
    await chooseAndLock(tester);
    expect(find.byKey(const Key('quickDrawInstruction')), findsNothing);
    expect(tester.widget<Text>(find.byKey(const Key('playerTitle0'))).data, 'Player 1: 0');
    expect(tester.widget<Text>(find.byKey(const Key('playerTitle1'))).data, 'Player 2: 0');
    expect(tester.widget<Text>(find.byKey(const Key('boardsState'))).data, 'Player 1: ready · Player 2: ready');
    expect(find.byKey(const Key('turnText')), findsNothing, reason: 'nothing to say while both are throwing');
  });

  testWidgets('the boards are kept when Play is left and opened again', (tester) async {
    await pumpScreen(tester, const TwoTargetPlayScreen());
    await chooseAndLock(tester);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: Text('Home'))));
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: TwoTargetPlayScreen())));
    await tester.pump();
    expect(container.read(playTargetsProvider).locked, isTrue);
    expect(find.byKey(const Key('playerTitle0')), findsOneWidget);
  });

  testWidgets('Choose boards again forgets the boards but keeps the scores', (tester) async {
    await pumpScreen(tester, const TwoTargetPlayScreen());
    await chooseAndLock(tester);
    container.read(gameProvider.notifier).state = Match(PlayMode.twoTargets).stuck(4, p, board: 1);
    await tester.tap(find.byKey(const Key('playChooseBoardsAgain')));
    await tester.pump();
    expect(instruction(tester), "Tap the centre of Player 1's board.");
    expect(container.read(gameProvider).players[1].total, 4);
  });

  testWidgets('the camera is set back to 1×, so both boards are in the picture', (tester) async {
    await pumpScreen(tester, const TwoTargetPlayScreen());
    expect(camera.zoom, 1);
  });

  testWidgets('Start with 2 players on 2 targets opens two-target Play', (tester) async {
    await pumpScreen(tester, const PlaySetupScreen());
    await tester.tap(find.text('2 players'));
    await tester.pump();
    await tester.tap(find.text('2 targets'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('playStart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TwoTargetPlayScreen), findsOneWidget);
  });

  testWidgets('Live test → Play on two targets plays the Quick draw recording', (tester) async {
    await pumpScreen(tester, const LiveTestScreen());
    container.read(playModeProvider.notifier).choose(PlayMode.solo);
    await tester.scrollUntilVisible(find.byKey(const Key('liveTestTwoTargets')), 200);
    await tester.tap(find.byKey(const Key('liveTestTwoTargets')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TwoTargetPlayScreen), findsOneWidget);
    expect(container.read(recordingChoiceProvider), same(quickDrawRecording));
    expect(container.read(gameProvider).mode, PlayMode.twoTargets);
  });

  group('two-target text', () {
    Match threeEach(Match m, int board) => m.stuck(1, p, board: board).stuck(1, p, board: board).stuck(1, p, board: board);

    test('while both are throwing, no headline', () {
      final m = Match(PlayMode.twoTargets).stuck(1, p, board: 0);
      expect((turnText(m), turnDetail(m)), (null, null));
    });

    test('one round complete: wait for the other player, then collect together', () {
      final m = threeEach(Match(PlayMode.twoTargets), 0);
      expect(turnText(m), 'Wait for Player 2');
      expect(turnDetail(m), 'Then collect your knives together.');
    });

    test('both complete: collect together, when no one is throwing', () {
      final m = threeEach(threeEach(Match(PlayMode.twoTargets), 0), 1);
      expect(turnText(m), 'Collect your knives');
      expect(turnDetail(m), 'Together, when no one is throwing.');
    });

    test('once collected, back to no headline', () {
      final m = threeEach(threeEach(Match(PlayMode.twoTargets), 0), 1).boardVisited(board: 0).boardVisited(board: 1);
      expect(turnText(m), isNull);
    });

    test('the winner at the end', () {
      var m = Match(PlayMode.twoTargets, rules: const GameSession(maxRounds: 1));
      m = threeEach(m, 0).stuck(5, p, board: 1).stuck(5, p, board: 1).stuck(5, p, board: 1);
      expect(turnText(m), 'Player 2 wins');
    });

    test("a board's message names its player", () {
      const episode = MotionEpisode(
          startFrame: 0, settledFrame: 1, start: Duration.zero, settled: Duration(seconds: 1), peakChange: 0.01, changeFromBefore: 0.01);
      expect(boardMessage(1, const ThrowEvent(ThrowOutcome(ThrowOutcomeKind.bounceOut), episode)), 'Player 2: Bounced off: 0.');
      expect(boardMessage(0, const ThrowEvent(ThrowOutcome(ThrowOutcomeKind.boardVisit), episode)), isNull);
      expect(boardMessage(0, const ThrowEvent(ThrowOutcome(ThrowOutcomeKind.sceneChanged), episode)), contains('Choose the boards again'));
    });

    test("each board's marks are drawn on that board: a knife's entry in its crop, moved by the crop's corner", () {
      final marks = [RoundMarks(), RoundMarks()];
      const episode = MotionEpisode(
          startFrame: 0, settledFrame: 1, start: Duration.zero, settled: Duration(seconds: 1), peakChange: 0.01, changeFromBefore: 0.01);
      marks[1].apply(
        const ThrowEvent(ThrowOutcome(ThrowOutcomeKind.stuck), episode,
            knifeId: 0, entry: EntryEstimate(point: Point2(5, 7), axis: Point2(1, 0), knifePixels: 100)),
        score: 4,
        newRound: true,
      );
      final boards = [boardAtCentre(100, 300), boardAtCentre(400, 300)];
      // The picture painted at half its 720 px width: scale 0.5.
      final painter = BoardMarksPainter(boards, marks, offsets: const [Point2(0, 0), Point2(300, 200)]);
      expect(
        (Canvas canvas) => painter.paint(canvas, const Size(360, 640)),
        paints..circle(x: (300 + 5) * 0.5, y: (200 + 7) * 0.5, radius: PlayOverlayPainter.radius),
      );
    });

    test('watch states, short', () {
      expect(boardsStateText([WatchState.motion, WatchState.blocked]), 'Player 1: throw seen · Player 2: someone at the board');
    });
  });
}
