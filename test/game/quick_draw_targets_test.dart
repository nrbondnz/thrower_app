import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/game/quick_draw_targets.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/tapped_target_locator.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/target_locator.dart';

/// A round board of outer radius 60 centred at ([cx], [cy]).
TargetCalibration boardAtCentre(double cx, double cy) {
  Ellipse at(double r) => Ellipse(cx: cx, cy: cy, semiMajor: 60 * r, semiMinor: 60 * r, angle: 0);
  return TargetCalibration(
    imageWidth: 720,
    imageHeight: 1280,
    boundaries: {for (final r in const [0.2, 0.4, 0.6, 0.8]) r: at(r)},
    outer: at(1),
  );
}

void main() {
  group('boardAt', () {
    test('a board found at the tap becomes a calibration in the picture\'s size', () {
      final b = boardAtCentre(100, 200);
      final found = TargetFound(boundaries: b.boundaries, outer: b.outer, confidence: 0.8, boundaryPoints: const {});
      final calibration = boardAt(TappedTargetsResult([found], 720, 1280))!;
      expect((calibration.imageWidth, calibration.imageHeight, calibration.outer.cx), (720, 1280, 100));
    });

    test('no board at the tap gives null', () {
      expect(boardAt(const TappedTargetsResult([TargetNotFound('none')], 720, 1280)), isNull);
    });
  });

  group('Quick draw boards', () {
    late ProviderContainer container;
    QuickDrawTargets state() => container.read(quickDrawTargetsProvider);
    QuickDrawTargetsNotifier notifier() => container.read(quickDrawTargetsProvider.notifier);

    setUp(() {
      container = ProviderContainer();
      container.listen(quickDrawTargetsProvider, (_, _) {}); // Keep the auto-disposed state alive.
    });
    tearDown(() => container.dispose());

    test('boards are kept in tap order: Player 1 first', () {
      notifier()
        ..add(boardAtCentre(600, 470))
        ..add(boardAtCentre(180, 460));
      expect([for (final b in state().boards) b.outer.cx], [600, 180]);
      expect(state().complete, isTrue);
    });

    test('a third tap is ignored: two players', () {
      notifier()
        ..add(boardAtCentre(100, 400))
        ..add(boardAtCentre(300, 400))
        ..add(boardAtCentre(500, 400));
      expect(state().boards, hasLength(2));
    });

    test('locking needs both boards', () {
      notifier()
        ..add(boardAtCentre(100, 400))
        ..lock();
      expect(state().locked, isFalse);
      notifier()
        ..add(boardAtCentre(300, 400))
        ..lock();
      expect(state().locked, isTrue);
    });

    test('choosing again forgets the boards and the lock', () {
      notifier()
        ..add(boardAtCentre(100, 400))
        ..add(boardAtCentre(300, 400))
        ..lock()
        ..clear();
      expect(state().boards, isEmpty);
      expect(state().locked, isFalse);
    });

    // Drawn boards (Mark, 2026-10-21): timed only, never scored.
    test('a drawn board is marked as an area, by its player', () {
      notifier()
        ..add(boardAtCentre(100, 400))
        ..add(boardAtCentre(300, 400), area: true);
      expect(state().areas, {1});
    });

    test('the areas are kept through adjusting, locking and unlocking', () {
      notifier()
        ..add(boardAtCentre(100, 400), area: true)
        ..add(boardAtCentre(300, 400), area: true)
        ..replace(0, boardAtCentre(120, 400));
      expect(state().areas, {0, 1}, reason: 'after replace');
      notifier().lock();
      expect(state().areas, {0, 1}, reason: 'after lock');
      notifier().unlock();
      expect(state().areas, {0, 1}, reason: 'after unlock');
    });

    test("a third, drawn board is ignored: no area for a player who isn't there", () {
      notifier()
        ..add(boardAtCentre(100, 400))
        ..add(boardAtCentre(300, 400))
        ..add(boardAtCentre(500, 400), area: true);
      expect(state().areas, isEmpty);
    });

    test('choosing again forgets the areas', () {
      notifier()
        ..add(boardAtCentre(100, 400), area: true)
        ..clear();
      expect(state().areas, isEmpty);
    });
  });
}
