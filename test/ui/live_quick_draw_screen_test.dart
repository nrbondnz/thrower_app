import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/live_camera.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/camera/target_camera.dart';
import 'package:thrower_app/game/quick_draw_judge.dart';
import 'package:thrower_app/game/quick_draw_watcher.dart';
import 'package:thrower_app/game/start_signal.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/quick_draw_match.dart';
import 'package:thrower_app/ui/camera_view.dart';
import 'package:thrower_app/ui/home_screen.dart';
import 'package:thrower_app/ui/live_quick_draw_screen.dart';
import 'package:thrower_app/ui/play_screen.dart';
import 'package:thrower_app/ui/play_setup_screen.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/tapped_target_locator.dart';
import 'package:thrower_app/vision/target_locator.dart';

import '../camera/recorded_camera_test.dart' show greyPack;
import '../game/quick_draw_targets_test.dart' show boardAtCentre;
import '../game/start_signal_test.dart' show FakeSignalSounds;
import '../settings/player_names_test.dart' show MemoryPlayerNamesStore;

void main() {
  late List<Point2> taps;
  late List<String> systemUiModes;
  late FakeSignalSounds sounds;
  var soundsReleased = 0;

  /// The camera's clock (frames and "go" are stamped with it).
  var clock = Duration.zero;

  Future<TappedTargetsResult> fakeLocate(_, Point2 tap) async {
    taps.add(tap);
    final b = boardAtCentre(tap.x * 8, tap.y * 6);
    return TappedTargetsResult(
      [TargetFound(boundaries: b.boundaries, outer: b.outer, confidence: 0.8, boundaryPoints: const {})],
      8,
      6,
    );
  }

  setUp(() {
    taps = [];
    systemUiModes = [];
    sounds = FakeSignalSounds();
    soundsReleased = 0;
    clock = Duration.zero;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') systemUiModes.add(call.arguments as String);
        return null;
      },
    );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );

  /// The app from Home, with the live Quick draw's camera replaced by [camera]
  /// (a recording stands in: tests have no camera).
  Future<void> pumpHome(
    WidgetTester tester,
    Future<TargetCamera> Function() camera, {
    List<String?> names = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerNamesStoreProvider.overrideWithValue(MemoryPlayerNamesStore(names)),
          liveQuickDrawCameraProvider.overrideWith((ref) => camera()),
          // Play's camera never starts in a test.
          cameraProvider.overrideWith((ref) => Completer<TargetCamera>().future),
          tapLocatorProvider.overrideWithValue(fakeLocate),
          // As the app's provider: auto-disposed, counting releases.
          signalSoundsProvider.overrideWith((ref) {
            ref.onDispose(() => soundsReleased++);
            return sounds;
          }),
          // A fixed pause of 1.5 s: go at 5.5 s after Start.
          startScheduleProvider.overrideWithValue(() => StartSchedule(const Duration(milliseconds: 1500))),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
  }

  Future<RecordedCamera> stillCamera() async {
    final c = RecordedCamera(
      greyPack(),
      recording: const Recording(name: 'Test', description: '', asset: ''),
      autoTick: false,
      clock: () => Duration.zero,
      decoder: decodeFramePureDart,
    );
    addTearDown(c.dispose);
    return c;
  }

  /// A still recording on the test's [clock].
  Future<RecordedCamera> clockCamera() async {
    final c = RecordedCamera(
      greyPack(),
      recording: const Recording(name: 'Test', description: '', asset: ''),
      autoTick: false,
      clock: () => clock,
      decoder: decodeFramePureDart,
    );
    addTearDown(c.dispose);
    return c;
  }

  String instruction(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('quickDrawInstruction'))).data!;

  Future<void> tapPicture(WidgetTester tester, double fx, double fy) async {
    final area = tester.getRect(find.byKey(const Key('quickDrawBoardTap')));
    await tester.tapAt(Offset(area.left + area.width * fx, area.top + area.height * fy));
    await tester.pumpAndSettle();
  }

  testWidgets('Home has Play (rounds of 3) and Quick draw (two throwers) as separate buttons', (tester) async {
    await pumpHome(tester, stillCamera);
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    expect(find.text('Rounds of 3 throws, 1 or 2 players'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Quick draw'), findsOneWidget);
    expect(find.text('Two throwers, on a start signal'), findsOneWidget);
  });

  testWidgets('Play opens the setup screen; Start with 1 player opens single-target Play', (tester) async {
    await pumpHome(tester, stillCamera);
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // The page transition.
    expect(find.byType(PlaySetupScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('playStart')), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('playStart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('Quick draw opens the camera full screen, asking for Player 1\'s board', (tester) async {
    await pumpHome(tester, stillCamera);
    await tester.tap(find.widgetWithText(FilledButton, 'Quick draw'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveQuickDrawScreen), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(systemUiModes, ['SystemUiMode.immersiveSticky']);
    expect(instruction(tester), "Tap the centre of Player 1's board.");
  });

  testWidgets('tapping both boards, in order, then locking them', (tester) async {
    await pumpHome(tester, stillCamera);
    await tester.tap(find.widgetWithText(FilledButton, 'Quick draw'));
    await tester.pumpAndSettle();
    await tapPicture(tester, 0.25, 0.5);
    expect(instruction(tester), "Tap the centre of Player 2's board.");
    await tapPicture(tester, 0.75, 0.5);
    expect(instruction(tester), startsWith('Both boards found. Drag an outline to fit its rings'));
    expect([for (final t in taps) (t.x, t.y)], [(0.25, 0.5), (0.75, 0.5)]);
    await tester.tap(find.byKey(const Key('quickDrawLock')));
    await tester.pump();
    expect(instruction(tester), startsWith('Boards locked. Throwers ready? Tap Start'));
  });

  group('the duel', () {
    Future<void> lockBoth(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Quick draw'));
      await tester.pumpAndSettle();
      await tapPicture(tester, 0.25, 0.5);
      await tapPicture(tester, 0.75, 0.5);
      await tester.tap(find.byKey(const Key('quickDrawLock')));
      await tester.pump();
    }

    /// Advances the camera's clock and the test's timers together.
    Future<void> wait(WidgetTester tester, Duration d) async {
      clock += d;
      await tester.pump(d);
    }

    // Backlog #10 (Nigel, 2026-10-19).
    testWidgets('Adjust boards unlocks them, keeping both; not while a round is on', (tester) async {
      await pumpHome(tester, clockCamera);
      await lockBoth(tester);
      await tester.tap(find.byKey(const Key('quickDrawAdjust')));
      await tester.pump();
      expect(find.byKey(const Key('quickDrawStart')), findsNothing);
      expect(find.byKey(const Key('quickDrawLock')), findsOneWidget);
      expect(find.byKey(const Key('boardsEditor')), findsOneWidget);
      await tester.tap(find.byKey(const Key('quickDrawLock')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('quickDrawStart')));
      await tester.pump();
      expect(find.byKey(const Key('quickDrawAdjust')), findsNothing);
      await tester.tap(find.byKey(const Key('quickDrawStop')));
      await tester.pump();
    });

    testWidgets('locked, Start appears; it lights the 5 lights a second apart with a beep each', (tester) async {
      await pumpHome(tester, clockCamera);
      await lockBoth(tester);
      expect(find.byKey(const Key('quickDrawStart')), findsOneWidget);
      await tester.tap(find.byKey(const Key('quickDrawStart')));
      await tester.pump();
      expect(find.byKey(const Key('quickDrawLight0On')), findsOneWidget);
      expect(find.byKey(const Key('quickDrawLight1Off')), findsOneWidget);
      expect(find.byKey(const Key('quickDrawNames')), findsNothing, reason: 'names are changed before Start');
      await wait(tester, const Duration(seconds: 4));
      expect(find.byKey(const Key('quickDrawLight4On')), findsOneWidget);
      expect(sounds.played, ['beep', 'beep', 'beep', 'beep', 'beep']);
      expect(instruction(tester), 'Wait for the long beep…');
      await tester.tap(find.byKey(const Key('quickDrawStop')));
      await tester.pump();
    });

    testWidgets(
      'at go: the lights go out and the go beep sounds, with nothing else on screen; both boards are watched from 1 s before',
      (tester) async {
        await pumpHome(tester, clockCamera);
        await lockBoth(tester);
        await tester.tap(find.byKey(const Key('quickDrawStart')));
        await tester.pump();
        await wait(tester, const Duration(seconds: 4)); // The 5th beep.
        expect(find.byKey(const Key('quickDrawWatchDebug')), findsNothing);
        await wait(tester, const Duration(milliseconds: 500)); // Go is at 5.5 s (pause 1.5 s).
        expect(find.byKey(const Key('quickDrawWatchDebug')), findsOneWidget, reason: 'watching from 4.5 s');
        await wait(tester, const Duration(seconds: 1));
        expect(find.byKey(const Key('quickDrawLights')), findsNothing);
        expect(find.text('GO!'), findsNothing, reason: 'the long beep is the signal (Nigel, 2026-10-16)');
        expect(sounds.played.last, 'go');
        expect(instruction(tester), 'Watching…');
        await wait(tester, const Duration(seconds: 5)); // Past the result window.
      },
    );

    testWidgets('with no throws, the result after the window: no winner, in large type, with a chime', (tester) async {
      await pumpHome(tester, clockCamera);
      await lockBoth(tester);
      await tester.tap(find.byKey(const Key('quickDrawStart')));
      await tester.pump();
      await wait(tester, const Duration(milliseconds: 5500)); // Go.
      expect(find.byKey(const Key('quickDrawResult')), findsNothing);
      for (var i = 0; i < 20; i++) {
        await wait(tester, const Duration(milliseconds: 250));
      }
      final headline = tester.widget<Text>(find.byKey(const Key('quickDrawHeadline')));
      expect(headline.data, 'No winner');
      expect(headline.style!.fontSize, greaterThanOrEqualTo(48), reason: 'readable from the throwing line');
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawResultPlayer0'))).data, '1:  no throw');
      expect(sounds.played.last, 'result');
    });

    /// Start, then a round with no throws, to its result.
    Future<void> playRound(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('quickDrawStart')));
      await tester.pump();
      await wait(tester, const Duration(milliseconds: 5500));
      for (var i = 0; i < 20; i++) {
        await wait(tester, const Duration(milliseconds: 250));
      }
    }

    String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

    testWidgets('Next round keeps the boards and shows Start, with the round and the match so far', (tester) async {
      await pumpHome(tester, clockCamera);
      await lockBoth(tester);
      await playRound(tester);
      await tester.tap(find.byKey(const Key('quickDrawNextRound')));
      await tester.pump();
      expect(find.byKey(const Key('quickDrawResult')), findsNothing);
      expect(find.byKey(const Key('quickDrawStart')), findsOneWidget);
      expect(instruction(tester), startsWith('Round 2 of 3 (Level 0–0). Throwers ready?'));
    });

    // The match (Nigel's brother, 2026-10-19): always three rounds; level
    // after three → extra rounds (Nigel).
    testWidgets("the result names the round, and the match so far", (tester) async {
      await pumpHome(tester, clockCamera);
      await lockBoth(tester);
      await playRound(tester);
      expect(text(tester, 'quickDrawRound'), 'Round 1 of 3');
      expect(text(tester, 'quickDrawMatch'), 'Level 0–0');
      expect(find.widgetWithText(FilledButton, 'Next round'), findsOneWidget);
    });

    testWidgets('level after three rounds: an extra round', (tester) async {
      await pumpHome(tester, clockCamera);
      await lockBoth(tester);
      for (var round = 0; round < 3; round++) {
        if (round > 0) {
          await tester.tap(find.byKey(const Key('quickDrawNextRound')));
          await tester.pump();
        }
        await playRound(tester);
      }
      expect(text(tester, 'quickDrawRound'), 'Round 3 of 3');
      expect(find.widgetWithText(FilledButton, 'Extra round'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quickDrawNextRound')));
      await tester.pump();
      expect(instruction(tester), startsWith('Extra round (Level 0–0).'));
    });

    testWidgets('Finish match asks, then ends the match on the rounds so far; New match starts again', (tester) async {
      await pumpHome(tester, clockCamera);
      await lockBoth(tester);
      expect(find.byKey(const Key('quickDrawFinishMatch')), findsNothing, reason: 'not before the first round');
      await playRound(tester);
      await tester.tap(find.byKey(const Key('quickDrawFinishMatch')));
      await tester.pumpAndSettle();
      expect(find.text('Finish the match now?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quickDrawFinishConfirm')));
      await tester.pumpAndSettle();
      expect(text(tester, 'quickDrawMatch'), 'Match drawn 0–0');
      expect(find.byKey(const Key('quickDrawNextRound')), findsNothing);
      expect(find.byKey(const Key('quickDrawStart')), findsNothing);
      await tester.tap(find.byKey(const Key('quickDrawNewMatch')));
      await tester.pump();
      expect(find.byKey(const Key('quickDrawResult')), findsNothing);
      expect(instruction(tester), startsWith('Boards locked.'));
    });

    testWidgets('Finish match between rounds shows the match result', (tester) async {
      await pumpHome(tester, clockCamera);
      await lockBoth(tester);
      await playRound(tester);
      await tester.tap(find.byKey(const Key('quickDrawNextRound')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('quickDrawFinishMatch')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quickDrawFinishConfirm')));
      await tester.pumpAndSettle();
      expect(text(tester, 'quickDrawMatch'), 'Match drawn 0–0');
      expect(find.byKey(const Key('quickDrawHeadline')), findsNothing);
      expect(find.byKey(const Key('quickDrawNewMatch')), findsOneWidget);
    });

    testWidgets('Cancel keeps the match going', (tester) async {
      await pumpHome(tester, clockCamera);
      await lockBoth(tester);
      await playRound(tester);
      await tester.tap(find.byKey(const Key('quickDrawFinishMatch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quickDrawNextRound')), findsOneWidget);
    });

    // Review Agent and Traceability Agent, 2026-10-15: the sounds were
    // released as soon as they were read, so no beeps on a real phone.
    testWidgets('the sounds stay loaded through a duel (not released while Quick draw is open)', (tester) async {
      await pumpHome(tester, clockCamera);
      await lockBoth(tester);
      await tester.tap(find.byKey(const Key('quickDrawStart')));
      await tester.pump();
      await wait(tester, const Duration(seconds: 7));
      expect(soundsReleased, 0);
      await tester.tap(find.byKey(const Key('quickDrawBack')));
      await tester.pumpAndSettle();
      expect(soundsReleased, 1, reason: 'released when Quick draw closes');
    });

    testWidgets('Stop stays available after go, until the result', (tester) async {
      await pumpHome(tester, clockCamera);
      await lockBoth(tester);
      await tester.tap(find.byKey(const Key('quickDrawStart')));
      await tester.pump();
      await wait(tester, const Duration(seconds: 6));
      expect(find.byKey(const Key('quickDrawStop')), findsOneWidget);
      await tester.tap(find.byKey(const Key('quickDrawStop')));
      await tester.pump();
      expect(find.byKey(const Key('quickDrawStart')), findsOneWidget);
    });

    testWidgets('Stop during the countdown: no go, back to Start', (tester) async {
      await pumpHome(tester, clockCamera);
      await lockBoth(tester);
      await tester.tap(find.byKey(const Key('quickDrawStart')));
      await tester.pump();
      await wait(tester, const Duration(seconds: 2));
      await tester.tap(find.byKey(const Key('quickDrawStop')));
      await tester.pump();
      await wait(tester, const Duration(seconds: 10));
      expect(sounds.played, ['beep', 'beep', 'beep']);
      expect(find.byKey(const Key('quickDrawStart')), findsOneWidget);
    });
  });

  testWidgets('choose boards again forgets the boards', (tester) async {
    await pumpHome(tester, stillCamera);
    await tester.tap(find.widgetWithText(FilledButton, 'Quick draw'));
    await tester.pumpAndSettle();
    await tapPicture(tester, 0.25, 0.5);
    await tester.tap(find.byKey(const Key('quickDrawStartAgain')));
    await tester.pump();
    expect(instruction(tester), "Tap the centre of Player 1's board.");
  });

  testWidgets('camera access refused: the camera error is shown, not a blank screen', (tester) async {
    await pumpHome(tester, () => Future.error(const CameraStartException(CameraFailure.denied)));
    await tester.tap(find.widgetWithText(FilledButton, 'Quick draw'));
    await tester.pumpAndSettle();
    expect(find.byType(CameraErrorView), findsOneWidget);
  });

  testWidgets('leaving brings the system bars back', (tester) async {
    await pumpHome(tester, stillCamera);
    await tester.tap(find.widgetWithText(FilledButton, 'Quick draw'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quickDrawBack')));
    await tester.pumpAndSettle();
    expect(find.byType(LiveQuickDrawScreen), findsNothing);
    expect(systemUiModes.last, 'SystemUiMode.edgeToEdge');
  });

  group('the result panel', () {
    Future<void> show(WidgetTester tester, QuickDrawVerdict? v, {bool skipped = false, QuickDrawMatch? match}) =>
        tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QuickDrawResultPanel(
                verdict: v,
                match: match ?? QuickDrawMatch(results: [v?.winner]),
                framesSkipped: skipped,
              ),
            ),
          ),
        );
    QuickDrawThrow at(int ms, {bool stuck = true, int score = 5}) => QuickDrawThrow(
      impact: Duration(milliseconds: 2800 + ms),
      stuck: stuck,
      score: stuck ? score : null,
    );
    const go = Duration(milliseconds: 2800);

    testWidgets("names the winner, and each player's time after go and score", (tester) async {
      await show(tester, judgeQuickDraw([at(850, stuck: false), at(817)], go));
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawHeadline'))).data, 'Player 2 wins');
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawResultPlayer0'))).data, '1:  0.85 s · bounced');
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawResultPlayer1'))).data, '2:  0.82 s · 5');
      expect(find.byKey(const Key('quickDrawFramesSkipped')), findsNothing);
    });

    testWidgets('a draw', (tester) async {
      await show(tester, judgeQuickDraw([at(817, score: 3), at(817, score: 3)], go));
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawHeadline'))).data, 'A draw');
    });

    testWidgets('a win on score says so', (tester) async {
      await show(tester, judgeQuickDraw([at(817, score: 3), at(817, score: 4)], go));
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawHeadline'))).data, 'Player 2 wins on score');
    });

    testWidgets('the match so far', (tester) async {
      await show(tester, judgeQuickDraw([at(850), at(817)], go), match: const QuickDrawMatch(results: [0, 1]));
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawRound'))).data, 'Round 2 of 3');
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawMatch'))).data, 'Level 1–1');
    });

    testWidgets("the leader's wins first", (tester) async {
      await show(tester, judgeQuickDraw([at(850), at(817)], go), match: const QuickDrawMatch(results: [1]));
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawMatch'))).data, 'Player 2 leads 1–0');
    });

    for (final (name, size) in [('upright', Size(390, 844)), ('sideways', Size(844, 390))]) {
      testWidgets('fits a phone held $name, with the longest lines', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await show(
          tester,
          judgeQuickDraw([at(817, score: 3), at(817, score: 4)], go),
          skipped: true,
          match: const QuickDrawMatch(results: [0, 1, null, 1]),
        );
        expect(tester.takeException(), isNull);
        final panel = tester.getRect(find.byKey(const Key('quickDrawResult')));
        expect(panel.left, greaterThanOrEqualTo(0));
        expect(panel.right, lessThanOrEqualTo(size.width));
        expect(panel.bottom, lessThanOrEqualTo(size.height));
      });
    }

    testWidgets('the match result, large and green', (tester) async {
      await show(tester, judgeQuickDraw([at(850), at(817)], go), match: const QuickDrawMatch(results: [1, 0, 1]));
      final line = tester.widget<Text>(find.byKey(const Key('quickDrawMatch')));
      expect(line.data, 'Player 2 wins the match 2–1');
      expect(line.style!.fontSize, greaterThanOrEqualTo(40), reason: 'readable from the throwing line');
      expect(line.style!.color, Colors.greenAccent);
    });

    testWidgets('an extra round', (tester) async {
      await show(tester, judgeQuickDraw([at(850), at(817)], go), match: const QuickDrawMatch(results: [0, 1, null, 1]));
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawRound'))).data, 'Extra round');
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawMatch'))).data, 'Player 2 wins the match 2–1');
    });

    // Named-players story (2026-10-19).
    testWidgets('names the winner and the match by name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickDrawResultPanel(
              verdict: judgeQuickDraw([at(850, stuck: false), at(817)], go),
              match: const QuickDrawMatch(results: [1, 1]),
              names: const ['Jo', 'Sam'],
            ),
          ),
        ),
      );
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawHeadline'))).data, 'Sam wins');
      expect(tester.widget<Text>(find.byKey(const Key('quickDrawMatch'))).data, 'Sam leads 2–0');
    });

    testWidgets('says so when frames were skipped (release builds have no debug line)', (tester) async {
      await show(tester, judgeQuickDraw([at(850), at(817)], go), skipped: true);
      expect(find.text('Some frames were skipped: times may be less exact.'), findsOneWidget);
    });
  });

  // Named-players story (Nigel, 2026-10-19): Quick draw uses Play's names.
  group('names', () {
    Future<void> openQuickDraw(WidgetTester tester, {List<String?> names = const []}) async {
      await pumpHome(tester, stillCamera, names: names);
      await tester.tap(find.widgetWithText(FilledButton, 'Quick draw'));
      await tester.pumpAndSettle();
    }

    testWidgets('choosing the boards asks for each player by name', (tester) async {
      await openQuickDraw(tester, names: ['Jo', 'Sam']);
      expect(instruction(tester), "Tap the centre of Jo's board.");
      await tapPicture(tester, 0.25, 0.5);
      expect(instruction(tester), "Tap the centre of Sam's board.");
    });

    testWidgets('Names changes them, the same names as Play', (tester) async {
      await openQuickDraw(tester);
      expect(instruction(tester), "Tap the centre of Player 1's board.");
      await tester.tap(find.byKey(const Key('quickDrawNames')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quickDrawName0')), 'Jo');
      await tester.tap(find.byKey(const Key('quickDrawNamesSave')));
      await tester.pumpAndSettle();
      expect(instruction(tester), "Tap the centre of Jo's board.");
      final container = ProviderScope.containerOf(tester.element(find.byType(LiveQuickDrawScreen)));
      expect(container.read(playerNamesProvider), ['Jo', null]);
    });

    testWidgets('Cancel leaves the names as they were', (tester) async {
      await openQuickDraw(tester, names: ['Jo']);
      await tester.tap(find.byKey(const Key('quickDrawNames')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quickDrawName0')), 'Kim');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(instruction(tester), "Tap the centre of Jo's board.");
    });
  });
}
