import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/scoring/target_model.dart';

void main() {
  group('TargetModel.ikthof scores a point with no blade width', () {
    final model = TargetModel.ikthof();
    const cases = <(String, TargetPoint, int)>[
      ('centre', TargetPoint(0, 0), 5),
      ('inside bull', TargetPoint(0.1, 0.1), 5),
      ('ring 4', TargetPoint(0.3, 0), 4),
      ('ring 3', TargetPoint(0, -0.5), 3),
      ('ring 2', TargetPoint(-0.7, 0), 2),
      ('ring 1', TargetPoint(0, 0.9), 1),
      ('just outside the target', TargetPoint(1.01, 0), 0),
      ('far outside the target', TargetPoint(3, 3), 0),
    ];
    for (final (name, point, expected) in cases) {
      test('$name $point scores $expected', () {
        expect(model.scoreAt(point), expected);
      });
    }
  });

  group('A point exactly on a line', () {
    test('scores the higher ring with the higher rule', () {
      expect(TargetModel.ikthof().scoreAt(const TargetPoint(0.2, 0)), 5);
    });

    test('scores the lower ring with the lower rule', () {
      final model = TargetModel.ikthof(lineTouchRule: LineTouchRule.lower);
      expect(model.scoreAt(const TargetPoint(0.2, 0)), 4);
    });

    test('on the outer edge scores 0 with the lower rule', () {
      final model = TargetModel.ikthof(lineTouchRule: LineTouchRule.lower);
      expect(model.scoreAt(const TargetPoint(1.0, 0)), 0);
    });
  });

  group('A blade touching a line', () {
    // Centre is 0.02 outside the bull's edge; a blade half-width of 0.03 touches it.
    const point = TargetPoint(0.22, 0);

    test('scores the higher ring with the higher rule', () {
      expect(TargetModel.ikthof().scoreAt(point, bladeHalfWidth: 0.03), 5);
    });

    test('scores the lower ring with the lower rule', () {
      final model = TargetModel.ikthof(lineTouchRule: LineTouchRule.lower);
      expect(model.scoreAt(const TargetPoint(0.38, 0), bladeHalfWidth: 0.03), 3);
    });

    test('that does not reach the line scores its own ring', () {
      expect(TargetModel.ikthof().scoreAt(const TargetPoint(0.3, 0), bladeHalfWidth: 0.03), 4);
    });

    test('touching the outer edge from outside scores 1 with the higher rule', () {
      expect(TargetModel.ikthof().scoreAt(const TargetPoint(1.02, 0), bladeHalfWidth: 0.03), 1);
    });
  });

  test('rings given out of order are sorted from the centre outwards', () {
    final model = TargetModel(rings: const [
      Ring(outerRadius: 1.0, score: 1),
      Ring(outerRadius: 0.5, score: 3),
    ]);
    expect(model.scoreAt(const TargetPoint(0.4, 0)), 3);
  });
}
