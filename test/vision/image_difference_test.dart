import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/image_difference.dart';

void main() {
  group('largestShape', () {
    List<bool> grid(List<String> rows) => [for (final r in rows) for (final c in r.split('')) c == '#'];

    test('counts the biggest 8-connected shape, diagonals included', () {
      final mask = grid([
        '##....',
        '..#..#',
        '...#..',
        '......',
      ]);
      expect(largestShape(mask, 6, 4), 4);
    });

    test('scattered specks stay small', () {
      final mask = grid([
        '#.#.#.',
        '......',
        '#.#.#.',
      ]);
      expect(largestShape(mask, 6, 3), 1);
    });

    test('nothing changed: 0', () {
      expect(largestShape(List.filled(12, false), 4, 3), 0);
    });
  });
}
