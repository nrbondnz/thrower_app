import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/live_camera.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/calibration_screen.dart';
import 'package:thrower_app/ui/play_screen.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/target_calibration.dart';

/// Height of a system navigation bar drawn over the app (Android 15 edge to
/// edge) or the iPhone home indicator.
const navBar = 48.0;

/// A target calibration, already locked (so Play shows its full layout).
class LockedCalibration extends CalibrationNotifier {
  @override
  CalibrationState? build() {
    Ellipse at(double r) => Ellipse(cx: 360, cy: 640, semiMajor: 200 * r, semiMinor: 140 * r, angle: math.pi / 2);
    return CalibrationState(
      TargetCalibration(
        imageWidth: 720,
        imageHeight: 1280,
        boundaries: {for (final r in const [0.2, 0.4, 0.6, 0.8]) r: at(r)},
        outer: at(1.0),
      ),
      locked: true,
    );
  }
}

Future<void> pumpWithNavBar(WidgetTester tester, Widget screen, {List overrides = const []}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(bottom: navBar * 3);
  tester.view.viewPadding = const FakeViewPadding(bottom: navBar * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      // The camera never starts in a test; the screens show their controls anyway.
      liveCameraProvider.overrideWith((ref) => Completer<LiveCamera>().future),
      ...overrides.cast(),
    ],
    child: MaterialApp(home: screen),
  ));
  await tester.pump();
}

void expectAboveNavBar(WidgetTester tester, Finder finder) {
  final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final bottom = tester.getRect(finder).bottom;
  expect(bottom, lessThanOrEqualTo(screenHeight - navBar), reason: 'bottom at $bottom, nav bar starts at ${screenHeight - navBar}');
}

void main() {
  testWidgets('Calibrate: the Find target button sits above the navigation bar', (tester) async {
    await pumpWithNavBar(tester, const CalibrationScreen());
    expectAboveNavBar(tester, find.widgetWithText(OutlinedButton, 'Find target'));
  });

  testWidgets('Play: the scores sit above the navigation bar', (tester) async {
    await pumpWithNavBar(tester, const PlayScreen(), overrides: [calibrationProvider.overrideWith(LockedCalibration.new)]);
    expectAboveNavBar(tester, find.byKey(const Key('gameText')));
  });
}
