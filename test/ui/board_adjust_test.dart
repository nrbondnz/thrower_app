import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/game/quick_draw_targets.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/calibration_editor.dart';
import 'package:thrower_app/ui/quick_draw_boards.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/target_calibration.dart';

import '../game/quick_draw_targets_test.dart' show boardAtCentre;

/// Backlog #10 (Nigel, 2026-10-19): each of two boards' outlines can be
/// dragged into place before locking, and Adjust boards unlocks them.
void main() {
  // A board of radius 60 at (200, 300) in a 720 × 1280 picture: its long-axis
  // handle at (260, 300), its short-axis handle at (200, 360).
  final board = boardAtCentre(200, 300);

  group('grabAt (shared with the single target)', () {
    final cases = <(String, Point2, CalibrationGrab?)>[
      ('inside the rings: the whole board', const Point2(210, 290), CalibrationGrab.move),
      ('on the long-axis handle', const Point2(262, 301), CalibrationGrab.major),
      ('on the short-axis handle', const Point2(199, 358), CalibrationGrab.minor),
      ('just outside the outer ring: still the board', const Point2(200, 365), CalibrationGrab.minor),
      ('well away from it: nothing', const Point2(500, 300), null),
    ];
    for (final (name, at, grab) in cases) {
      test(name, () => expect(grabAt(board, at, 8), grab));
    }

    test("a small board on screen (its handles' reach covers its middle): the middle still moves it", () {
      expect(grabAt(board, const Point2(201, 300), 64), CalibrationGrab.move);
      expect(grabAt(board, const Point2(250, 300), 64), CalibrationGrab.major, reason: 'nearer the handle');
    });

    test('dragging the whole board moves it; a handle turns or stretches it', () {
      final moved = dragged(board, CalibrationGrab.move, delta: const Point2(10, -5), at: const Point2(0, 0));
      expect((moved.outer.cx, moved.outer.cy), (210, 295));
      final stretched = dragged(board, CalibrationGrab.major, delta: const Point2(0, 0), at: const Point2(290, 300));
      expect(stretched.outer.semiMajor, closeTo(90, 0.001));
    });
  });

  group('the boards', () {
    late ProviderContainer container;
    QuickDrawTargetsNotifier notifier() => container.read(quickDrawTargetsProvider.notifier);
    QuickDrawTargets targets() => container.read(quickDrawTargetsProvider);

    setUp(() {
      container = ProviderContainer();
      container.listen(quickDrawTargetsProvider, (_, _) {});
      notifier()
        ..add(board)
        ..add(boardAtCentre(500, 300));
    });
    tearDown(() => container.dispose());

    test('one board replaced, the other untouched', () {
      notifier().replace(1, boardAtCentre(520, 310));
      expect([for (final b in targets().boards) b.outer.cx], [200, 520]);
    });

    test('not once locked', () {
      notifier()
        ..lock()
        ..replace(1, boardAtCentre(520, 310));
      expect(targets().boards[1].outer.cx, 500);
    });

    test('Adjust boards unlocks them, keeping both', () {
      notifier()
        ..lock()
        ..unlock();
      expect((targets().locked, targets().boards.length), (false, 2));
    });
  });

  group('BoardsEditor', () {
    /// The editor over a 720 × 1280 picture shown at half size.
    Future<List<(int, TargetCalibration)>> pump(WidgetTester tester) async {
      final changes = <(int, TargetCalibration)>[];
      await tester.pumpWidget(MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 360,
            height: 640,
            child: BoardsEditor(
              targets: QuickDrawTargets(boards: [board, boardAtCentre(500, 300)]),
              onAdjust: (i, b) => changes.add((i, b)),
            ),
          ),
        ),
      ));
      return changes;
    }

    testWidgets('dragging inside board 2 moves board 2 only', (tester) async {
      final changes = await pump(tester);
      // Board 2's centre (500, 300) is at (250, 150) on screen.
      final finger = await tester.startGesture(const Offset(250, 150));
      for (var i = 0; i < 4; i++) {
        await finger.moveBy(const Offset(10, 0));
        await tester.pump();
      }
      await finger.up();
      expect(changes, isNotEmpty);
      expect(changes.every((c) => c.$1 == 1), isTrue);
      expect(changes.any((c) => c.$2.outer.cx > 500), isTrue, reason: 'moved right');
    });

    testWidgets("dragging board 1's long-axis handle stretches board 1", (tester) async {
      final changes = await pump(tester);
      // Board 1's long-axis handle (260, 300) is at (130, 150) on screen.
      await tester.dragFrom(const Offset(130, 150), const Offset(20, 0));
      expect(changes.every((c) => c.$1 == 0), isTrue);
      expect(changes.last.$2.outer.semiMajor, greaterThan(60));
    });

    testWidgets('dragging away from both boards changes nothing', (tester) async {
      final changes = await pump(tester);
      await tester.dragFrom(const Offset(180, 500), const Offset(20, 0));
      expect(changes, isEmpty);
    });

    testWidgets('draws both boards with their handles', (tester) async {
      await pump(tester);
      expect(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is BoardsPainter && (w.painter! as BoardsPainter).handles),
        findsOneWidget,
      );
    });
  });
}
