import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/calibration_editor.dart';
import 'package:thrower_app/ui/calibration_screen.dart';
import 'package:thrower_app/ui/watch_status.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/locate_in_frame.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/target_locator.dart';

// Image 640 × 480 shown at 320 × 240 (scale 0.5).
const outer = Ellipse(cx: 320, cy: 240, semiMajor: 160, semiMinor: 120, angle: math.pi / 2);
final calibration = TargetCalibration(
  imageWidth: 640,
  imageHeight: 480,
  boundaries: {0.8: Ellipse(cx: 320, cy: 240, semiMajor: 128, semiMinor: 96, angle: math.pi / 2)},
  outer: outer,
);

void main() {
  group('CalibrationEditor', () {
    Future<List<TargetCalibration>> pump(WidgetTester tester, {bool locked = false}) async {
      final changes = <TargetCalibration>[];
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 240,
            child: CalibrationEditor(calibration: calibration, locked: locked, onChanged: changes.add),
          ),
        ),
      ));
      return changes;
    }

    Offset screen(WidgetTester tester, double x, double y) =>
        tester.getTopLeft(find.byType(CalibrationEditor)) + Offset(x * 0.5, y * 0.5);

    testWidgets('dragging inside the rings moves them (in image pixels)', (tester) async {
      final changes = await pump(tester);
      await tester.dragFrom(screen(tester, 320, 240), const Offset(20, 10));
      expect(changes, isNotEmpty);
      // 20 × 10 screen pixels at scale 0.5 = 40 × 20 image pixels in total,
      // spread over the drag's updates (each is applied to the original here).
      final last = changes.last.outer;
      expect(last.cx, greaterThan(320));
      expect(last.cy, greaterThan(240));
    });

    testWidgets('dragging the long-axis handle reshapes the rings', (tester) async {
      final changes = await pump(tester);
      final handle = calibration.majorHandle; // (320, 400) in the image.
      await tester.dragFrom(screen(tester, handle.x, handle.y), const Offset(0, 20));
      expect(changes.last.outer.semiMajor, closeTo(200, 2));
      expect(changes.last.outer.cx, 320);
    });

    testWidgets('dragging outside the rings does nothing', (tester) async {
      final changes = await pump(tester);
      await tester.dragFrom(screen(tester, 20, 20), const Offset(20, 20));
      expect(changes, isEmpty);
    });

    testWidgets('once locked, a tap reports its image pixel (for scoring)', (tester) async {
      final taps = <Point2>[];
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 240,
            child: CalibrationEditor(calibration: calibration, locked: true, onChanged: (_) {}, onTapLocked: taps.add),
          ),
        ),
      ));
      await tester.tapAt(screen(tester, 400, 300));
      expect(taps.single.x, closeTo(400, 0.5));
      expect(taps.single.y, closeTo(300, 0.5));
    });

    testWidgets('while adjusting, taps are not reported for scoring', (tester) async {
      final taps = <Point2>[];
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 240,
            child: CalibrationEditor(calibration: calibration, locked: false, onChanged: (_) {}, onTapLocked: taps.add),
          ),
        ),
      ));
      await tester.tapAt(screen(tester, 400, 300));
      expect(taps, isEmpty);
    });

    testWidgets('a locked calibration cannot be dragged', (tester) async {
      final changes = await pump(tester, locked: true);
      await tester.dragFrom(screen(tester, 320, 240), const Offset(20, 10));
      expect(changes, isEmpty);
      expect(find.byKey(const Key('calibrationEditor')), findsNothing);
    });
  });

  group('CalibrationControls', () {
    Future<void> pump(WidgetTester tester, {required bool canAdjust, required bool locked}) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: CalibrationControls(
              status: 'status',
              canAdjust: canAdjust,
              locked: locked,
              onFind: () {},
              onLock: () {},
              onUnlock: () {},
              findLabel: 'Find again',
            ),
          ),
        ));

    testWidgets('while adjusting: safety note, Find again and Lock target', (tester) async {
      await pump(tester, canAdjust: true, locked: false);
      expect(find.text(CalibrationControls.safetyNote), findsOneWidget);
      expect(find.text('Lock target'), findsOneWidget);
      expect(find.text('Find again'), findsOneWidget);
    });

    testWidgets('once locked: only Re-calibrate, no safety note', (tester) async {
      await pump(tester, canAdjust: false, locked: true);
      expect(find.text(CalibrationControls.safetyNote), findsNothing);
      expect(find.text('Re-calibrate'), findsOneWidget);
      expect(find.text('Lock target'), findsNothing);
    });

    testWidgets('before anything is found: no Lock target', (tester) async {
      await pump(tester, canAdjust: false, locked: false);
      expect(find.text('Lock target'), findsNothing);
      expect(find.text(CalibrationControls.safetyNote), findsNothing);
    });
  });

  group('CalibrationNotifier', () {
    test('start, adjust, lock, then adjustments are ignored until unlocked', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(calibrationProvider.notifier);
      expect(container.read(calibrationProvider), isNull);

      notifier.start(calibration);
      final moved = calibration.moved(5, 0);
      notifier.adjust(moved);
      expect(container.read(calibrationProvider)!.calibration, moved);

      notifier.lock();
      notifier.adjust(calibration.moved(50, 0));
      expect(container.read(calibrationProvider)!.calibration, moved);
      expect(container.read(calibrationProvider)!.locked, isTrue);

      notifier.unlock();
      expect(container.read(calibrationProvider)!.locked, isFalse);
      expect(container.read(calibrationProvider)!.calibration, moved);
    });
  });

  group('calibrationFrom', () {
    test('uses the found rings', () {
      final c = calibrationFrom(FrameLocateResult(
        TargetFound(boundaries: {0.8: outer.scaled(0.8)}, outer: outer, confidence: 0.9, boundaryPoints: {}),
        640,
        480,
      ))!;
      expect(c.outer, outer);
      expect(c.imageWidth, 640);
    });

    test("uses a rejected attempt, so a near miss can be fixed by hand", () {
      final c = calibrationFrom(FrameLocateResult(
        TargetNotFound('Ring centres disagree', attempted: {0.4: outer.scaled(0.4), 0.8: outer.scaled(0.8)}),
        640,
        480,
      ))!;
      expect(c.outer.semiMajor, closeTo(160, 1e-9));
    });

    test('gives nothing when there was no attempt', () {
      expect(calibrationFrom(const FrameLocateResult(TargetNotFound('nothing'), 640, 480)), isNull);
    });
  });

  group('watchStatusText', () {
    test('describes each state', () {
      expect(watchStatusText(WatchState.watching, null), 'Board still: watching');
      expect(watchStatusText(WatchState.motion, null), 'Motion');
      expect(watchStatusText(WatchState.blocked, null), 'Something is in front of the board');
    });
    test('summarises the last episode', () {
      const e = MotionEpisode(
        startFrame: 1,
        settledFrame: 20,
        start: Duration(milliseconds: 1000),
        settled: Duration(milliseconds: 2200),
        peakChange: 0.006,
        changeFromBefore: 0.007,
      );
      expect(watchStatusText(WatchState.watching, e),
          'Board still: watching\nLast: 1.2 s of motion, peak 0.6%, 0.7% changed from before');
    });
  });

  group('lockedStatus', () {
    test('invites a tap before any', () {
      expect(lockedStatus(null), 'Target locked. Tap the picture to test scoring.');
    });
    test('shows the score of the last tap', () {
      expect(lockedStatus(4), startsWith('Score here: 4.'));
    });
    test('explains a zero', () {
      expect(lockedStatus(0), startsWith('Score here: 0 (outside the target).'));
    });
  });

  test('status suggests adjusting by hand after a near miss', () {
    final status = calibrationStatus(
      FrameLocateResult(TargetNotFound('Ring centres disagree', attempted: {0.8: outer}), 640, 480),
      searching: false,
    );
    expect(status, contains('Adjust the rings by hand'));
  });
}
