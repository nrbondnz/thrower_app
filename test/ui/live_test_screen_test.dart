import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/camera/target_camera.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/ui/camera_view.dart';
import 'package:thrower_app/ui/home_screen.dart';
import 'package:thrower_app/ui/live_test_screen.dart';
import 'package:thrower_app/ui/play_screen.dart';

import '../camera/recorded_camera_test.dart' show greyPack;
import 'system_bars_test.dart' show LockedCalibration;

const testRecording = Recording(name: 'Test', description: '', asset: '');

Future<ProviderContainer> pump(WidgetTester tester, Widget home, {TargetCamera? camera, List overrides = const []}) async {
  final container = ProviderContainer(overrides: [
    // No camera or recording loads in these tests unless a test supplies one.
    cameraProvider.overrideWith((ref) => camera ?? Completer<TargetCamera>().future),
    ...overrides.cast(),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(home: home)));
  return container;
}

void main() {
  testWidgets('the home screen opens Live test, which offers Target 1 and Target 2', (tester) async {
    await pump(tester, const HomeScreen());
    await tester.tap(find.text('Live test'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveTestScreen), findsOneWidget);
    expect(find.text('Target 1'), findsOneWidget);
    expect(find.text('Target 2'), findsOneWidget);
  });

  testWidgets('calibrate needs a target chosen; play needs it calibrated', (tester) async {
    final container = await pump(tester, const LiveTestScreen());
    FilledButton button(String text) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, text));
    expect(button('1. Calibrate target').onPressed, isNull);

    await tester.tap(find.text('Target 1'));
    await tester.pump();
    expect(container.read(recordingChoiceProvider), same(liveTestRecordings[0]));
    expect(button('1. Calibrate target').onPressed, isNotNull);
    expect(button('2. Play').onPressed, isNull);
  });

  testWidgets('leaving Live test goes back to the phone camera', (tester) async {
    final container = await pump(tester, const HomeScreen());
    await tester.tap(find.text('Live test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Target 2'));
    await tester.pump();
    expect(container.read(recordingChoiceProvider), same(liveTestRecordings[1]));

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(container.read(recordingChoiceProvider), isNull);
  });

  test('switching camera starts a new calibration and a new game', () {
    final container = ProviderContainer(overrides: [calibrationProvider.overrideWith(LockedCalibration.new)]);
    addTearDown(container.dispose);
    container.read(gameProvider.notifier).state = const GameSession().bounceOut();
    expect(container.read(calibrationProvider), isNotNull);

    container.read(recordingChoiceProvider.notifier).use(liveTestRecordings[0]);
    expect(container.read(gameProvider).rounds, isEmpty);
    // The overridden notifier rebuilds too (a real one starts empty).
    expect(container.read(calibrationProvider)?.locked, isTrue);
  });

  testWidgets('the camera view shows a recording with its playing time', (tester) async {
    final camera = RecordedCamera(greyPack(), recording: testRecording, autoTick: false, clock: () => Duration.zero);
    addTearDown(camera.dispose);
    await pump(tester, const Scaffold(body: CameraView()), camera: camera);
    await tester.pump();
    expect(find.text('Test · 0:00 / 0:02'), findsOneWidget);
  });

  testWidgets('Play starts the recording from the beginning, and can replay it', (tester) async {
    var now = Duration.zero;
    final camera = RecordedCamera(greyPack(), recording: testRecording, autoTick: false, clock: () => now);
    addTearDown(camera.dispose);
    await pump(tester, const PlayScreen(), camera: camera, overrides: [
      calibrationProvider.overrideWith(LockedCalibration.new),
    ]);
    await tester.pump();
    await tester.pump();
    expect(camera.playing.value, isTrue);

    now = const Duration(seconds: 10);
    camera.tick();
    await tester.pump();
    expect(find.text('Recording finished: play again'), findsOneWidget);

    await tester.tap(find.byKey(const Key('replayRecording')));
    await tester.pump();
    expect(camera.playing.value, isTrue);
    expect(camera.current.value!.index, 0);
  });
}
