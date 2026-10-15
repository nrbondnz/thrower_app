import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/live_camera.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/camera/target_camera.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/camera_view.dart';
import 'package:thrower_app/ui/home_screen.dart';
import 'package:thrower_app/ui/live_quick_draw_screen.dart';
import 'package:thrower_app/ui/play_screen.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/tapped_target_locator.dart';
import 'package:thrower_app/vision/target_locator.dart';

import '../camera/recorded_camera_test.dart' show greyPack;
import '../game/quick_draw_targets_test.dart' show boardAtCentre;

void main() {
  late List<Point2> taps;
  late List<String> systemUiModes;

  Future<TappedTargetsResult> fakeLocate(_, Point2 tap) async {
    taps.add(tap);
    final b = boardAtCentre(tap.x * 8, tap.y * 6);
    return TappedTargetsResult([TargetFound(boundaries: b.boundaries, outer: b.outer, confidence: 0.8, boundaryPoints: const {})], 8, 6);
  }

  setUp(() {
    taps = [];
    systemUiModes = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setEnabledSystemUIMode') systemUiModes.add(call.arguments as String);
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

  /// The app from Home, with the live Quick draw's camera replaced by [camera]
  /// (a recording stands in: tests have no camera).
  Future<void> pumpHome(WidgetTester tester, Future<TargetCamera> Function() camera) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        liveQuickDrawCameraProvider.overrideWith((ref) => camera()),
        // Play's camera never starts in a test.
        cameraProvider.overrideWith((ref) => Completer<TargetCamera>().future),
        tapLocatorProvider.overrideWithValue(fakeLocate),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
  }

  Future<RecordedCamera> stillCamera() async {
    final c = RecordedCamera(greyPack(), recording: const Recording(name: 'Test', description: '', asset: ''),
        autoTick: false, clock: () => Duration.zero, decoder: decodeFramePureDart);
    addTearDown(c.dispose);
    return c;
  }

  String instruction(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('quickDrawInstruction'))).data!;

  Future<void> tapPicture(WidgetTester tester, double fx, double fy) async {
    final area = tester.getRect(find.byKey(const Key('quickDrawBoardTap')));
    await tester.tapAt(Offset(area.left + area.width * fx, area.top + area.height * fy));
    await tester.pumpAndSettle();
  }

  testWidgets('Home has Play (rounds on one target) and Quick draw (two throwers) as separate buttons', (tester) async {
    await pumpHome(tester, stillCamera);
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    expect(find.text('Rounds on one target'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Quick draw'), findsOneWidget);
    expect(find.text('Two throwers, on a start signal'), findsOneWidget);
  });

  testWidgets('Play still opens single-target Play', (tester) async {
    await pumpHome(tester, stillCamera);
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // The page transition.
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
    expect(instruction(tester), 'Both boards found: lock them, or start again.');
    expect([for (final t in taps) (t.x, t.y)], [(0.25, 0.5), (0.75, 0.5)]);
    await tester.tap(find.byKey(const Key('quickDrawLock')));
    await tester.pump();
    expect(instruction(tester), 'Boards locked.');
  });

  testWidgets('start again forgets the boards', (tester) async {
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
}
