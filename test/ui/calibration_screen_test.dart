import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/ui/calibration_screen.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/locate_in_frame.dart';
import 'package:thrower_app/vision/target_locator.dart';

void main() {
  const ring = Ellipse(cx: 1, cy: 1, semiMajor: 1, semiMinor: 1, angle: 0);

  test('prompts before the first search', () {
    expect(calibrationStatus(null, searching: false), startsWith('Point the phone'));
  });

  test('shows progress while searching', () {
    expect(calibrationStatus(null, searching: true), 'Looking for the target…');
  });

  test('reports confidence and time when found', () {
    final found = FrameLocateResult(
      TargetFound(boundaries: {0.8: ring}, outer: ring, confidence: 0.853, boundaryPoints: {}),
      600,
      800,
    );
    expect(calibrationStatus(found, searching: false, millis: 420), 'Target found: confidence 85% (420 ms)');
  });

  test('says how far the camera zoomed in', () {
    final found = FrameLocateResult(
      TargetFound(boundaries: {0.8: ring}, outer: ring, confidence: 0.853, boundaryPoints: {}),
      600,
      800,
    );
    expect(calibrationStatus(found, searching: false, millis: 900, zoom: 2.44),
        'Target found: confidence 85%, zoomed in 2.4× (900 ms)');
  });

  test('suggests centring the board when its position held the zoom back', () {
    final found = FrameLocateResult(
      TargetFound(boundaries: {0.8: ring}, outer: ring, confidence: 0.853, boundaryPoints: {}),
      600,
      800,
    );
    expect(calibrationStatus(found, searching: false, zoom: 1.5, offCentre: true),
        endsWith('\nCentre the board in the picture for a closer view.'));
  });

  test('reports the reason when not found', () {
    const found = FrameLocateResult(TargetNotFound('No large red area found'), 600, 800);
    expect(calibrationStatus(found, searching: false, millis: 300),
        'Target not found: No large red area found (300 ms). Try Tap the board.');
  });

  // Gapped-rings story (2026-10-21): when Find target can't find the rings,
  // the user taps the board's middle.
  test('a near miss suggests adjusting, finding again, or tapping the board', () {
    final found = FrameLocateResult(
      TargetNotFound('Rings too unclear', attempted: {0.8: ring}),
      600,
      800,
    );
    expect(calibrationStatus(found, searching: false), endsWith('Adjust the rings by hand, find again, or tap the board.'));
  });

  Widget controls({bool locked = false, bool tapMode = false, bool canAdjust = false}) => MaterialApp(
        home: Scaffold(
          body: CalibrationControls(
            status: tapMode ? tapTheBoardStatus : 'status',
            canAdjust: canAdjust,
            locked: locked,
            tapMode: tapMode,
            onFind: () {},
            onLock: () {},
            onUnlock: () {},
            onTapBoard: () {},
            findLabel: 'Find target',
          ),
        ),
      );

  testWidgets('offers Tap the board until the target is locked', (tester) async {
    await tester.pumpWidget(controls());
    expect(find.text('Tap the board'), findsOneWidget);
    await tester.pumpWidget(controls(locked: true));
    expect(find.text('Tap the board'), findsNothing);
  });

  testWidgets('tap mode: asks for the tap, offers Cancel tap, and shows the safety note', (tester) async {
    await tester.pumpWidget(controls(tapMode: true));
    expect(find.text('Tap the middle of the board in the picture.'), findsOneWidget);
    expect(find.text('Cancel tap'), findsOneWidget);
    expect(find.text(CalibrationControls.safetyNote), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Find target')).onPressed, isNull);
  });
}
