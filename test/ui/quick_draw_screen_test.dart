import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/game/quick_draw_watcher.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/live_test_screen.dart';
import 'package:thrower_app/ui/quick_draw_screen.dart';
import 'package:thrower_app/ui/recorded_preview.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/tapped_target_locator.dart';
import 'package:thrower_app/vision/target_locator.dart';

import '../camera/recorded_camera_test.dart' show FakeSound, greyPack;
import '../game/quick_draw_targets_test.dart' show boardAtCentre;

void main() {
  late List<String> systemUiModes;
  late Duration now;
  late FakeSound sound;
  late RecordedCamera camera;

  /// Taps the screen passed on to the board finder (image pixels), and
  /// whether it "finds" a board there.
  late List<Point2> taps;
  late bool boardThere;

  Future<TappedTargetsResult> fakeLocate(_, Point2 tap) async {
    taps.add(tap);
    if (!boardThere) return const TappedTargetsResult([TargetNotFound('none')], 8, 6);
    final b = boardAtCentre(tap.x, tap.y);
    return TappedTargetsResult([TargetFound(boundaries: b.boundaries, outer: b.outer, confidence: 0.8, boundaryPoints: const {})], 8, 6);
  }

  setUp(() {
    systemUiModes = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') systemUiModes.add(call.arguments as String);
      return null;
    });
    now = Duration.zero;
    taps = [];
    boardThere = true;
    sound = FakeSound();
    camera = RecordedCamera(greyPack(), recording: quickDrawRecording, autoTick: false, clock: () => now, decoder: decodeFramePureDart, sound: sound);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    return camera.dispose();
  });

  Future<void> pumpLiveTest(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        quickDrawCameraProvider.overrideWith((ref) async => camera),
        tapLocatorProvider.overrideWithValue(fakeLocate),
      ],
      child: const MaterialApp(home: LiveTestScreen()),
    ));
    await tester.tap(find.text('Quick draw').last);
    await tester.pumpAndSettle();
  }

  testWidgets('Live test opens Quick draw, which shows the clip full screen with the system bars hidden', (tester) async {
    await pumpLiveTest(tester);
    expect(find.byType(QuickDrawScreen), findsOneWidget);
    expect(find.byType(RecordedPreview), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(systemUiModes, ['SystemUiMode.immersiveSticky']);
  });

  testWidgets('Play starts the clip and its sound; the button hides while it plays and returns as "Play again"', (tester) async {
    await pumpLiveTest(tester);
    await tester.tap(find.byKey(const Key('quickDrawPlay')));
    await tester.pump();
    expect(camera.playing.value, isTrue);
    expect(sound.calls, ['play']);
    expect(find.byKey(const Key('quickDrawPlay')), findsNothing);

    now = const Duration(seconds: 10);
    camera.tick();
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Play again'), findsOneWidget);
  });

  testWidgets('leaving Quick draw brings the system bars back', (tester) async {
    await pumpLiveTest(tester);
    await tester.tap(find.byKey(const Key('quickDrawBack')));
    await tester.pumpAndSettle();
    expect(find.byType(QuickDrawScreen), findsNothing);
    expect(systemUiModes.last, 'SystemUiMode.edgeToEdge');
  });

  String instruction(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('quickDrawInstruction'))).data!;

  /// A tap on the picture at ([fx], [fy]) of its width and height.
  Future<void> tapPicture(WidgetTester tester, double fx, double fy) async {
    final area = tester.getRect(find.byKey(const Key('quickDrawBoardTap')));
    await tester.tapAt(Offset(area.left + area.width * fx, area.top + area.height * fy));
    await tester.pumpAndSettle();
  }

  testWidgets("asks for Player 1's board, then Player 2's, in tap order", (tester) async {
    await pumpLiveTest(tester);
    expect(instruction(tester), "Tap the centre of Player 1's board.");
    await tapPicture(tester, 0.75, 0.5);
    expect(instruction(tester), "Tap the centre of Player 2's board.");
    await tapPicture(tester, 0.25, 0.5);
    expect(instruction(tester), 'Both boards found: lock them, or start again.');
    // Taps reach the finder in the picture's pixels (8 × 6 here).
    expect([for (final t in taps) (t.x.round(), t.y.round())], [(6, 3), (2, 3)]);
  });

  testWidgets('a tap that finds no board says so, and asks again', (tester) async {
    await pumpLiveTest(tester);
    boardThere = false;
    await tapPicture(tester, 0.5, 0.5);
    expect(instruction(tester), "No board found there. Tap the centre of Player 1's board.");
  });

  testWidgets('once both are found, taps stop and the boards can be locked', (tester) async {
    await pumpLiveTest(tester);
    await tapPicture(tester, 0.75, 0.5);
    await tapPicture(tester, 0.25, 0.5);
    expect(find.byKey(const Key('quickDrawBoardTap')), findsNothing);
    await tester.tap(find.byKey(const Key('quickDrawLock')));
    await tester.pump();
    expect(instruction(tester), 'Boards locked. Press Play.');
    expect(find.byKey(const Key('quickDrawLock')), findsNothing);
  });

  testWidgets('start again forgets the boards and rewinds the clip', (tester) async {
    await pumpLiveTest(tester);
    await tapPicture(tester, 0.75, 0.5);
    camera.restart();
    await tester.pump();
    await tester.tap(find.byKey(const Key('quickDrawStartAgain')));
    await tester.pump();
    expect(instruction(tester), "Tap the centre of Player 1's board.");
    expect(camera.playing.value, isFalse);
  });

  testWidgets("the boards can't be tapped while the clip plays", (tester) async {
    await pumpLiveTest(tester);
    camera.restart();
    await tester.pump();
    expect(find.byKey(const Key('quickDrawBoardTap')), findsNothing);
  });

  group('the line under each board', () {
    test('is empty until the throw is in', () {
      expect(throwText(null, camera), isNull);
    });

    test("a stuck knife shows when it arrived, on the clip's timeline, and its score", () {
      now = const Duration(seconds: 10);
      camera.restart();
      final t = QuickDrawThrow(impact: const Duration(seconds: 10, milliseconds: 3617), stuck: true, score: 5);
      expect(throwText(t, camera), '3.62 s · 5');
    });

    test('a bounce-out says so', () {
      camera.restart();
      expect(throwText(const QuickDrawThrow(impact: Duration(milliseconds: 3650), stuck: false), camera), '3.65 s · bounced');
    });

    test("a stuck knife whose entry wasn't found shows ?", () {
      camera.restart();
      expect(throwText(const QuickDrawThrow(impact: Duration(seconds: 1), stuck: true), camera), '1.00 s · ?');
    });
  });
}
