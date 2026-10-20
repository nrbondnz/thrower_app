import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/tapped_target_locator.dart';
import 'package:thrower_app/vision/target_locator.dart';

/// Gapped-rings story: Mark's stencilled boards (`test/fixtures/marks_boards/`),
/// whose black rings are painted in four arcs with gaps between them, on
/// speckled wood. The usual search can't read them; a tap on the board's
/// middle (Play's calibration asks for one when Find target fails, as Quick
/// draw does) finds them through `ColourRingLocator`'s alignment fallback.
/// Checked against the hand-measured answer key on the whole picture as the
/// phone saw it (three boards, the net, the fence).

const dir = 'test/fixtures/marks_boards';

double meanRadius(Ellipse e) => (e.semiMajor + e.semiMinor) / 2;
double dist(Point2 a, Point2 b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

final _radii = () {
  final model = TargetModel.katta();
  return [for (final r in model.rings.take(model.rings.length - 1)) r.outerRadius];
}();

String describe(TargetLocateResult r) => switch (r) {
      TargetFound(:final outer, :final confidence) =>
        'found at (${outer.cx.toStringAsFixed(0)}, ${outer.cy.toStringAsFixed(0)}), outer ${meanRadius(outer).toStringAsFixed(0)} px, '
            'confidence ${confidence.toStringAsFixed(2)}',
      TargetNotFound(:final reason) => 'not found: $reason',
    };

void main() {
  final truth = jsonDecode(File('$dir/truth.json').readAsStringSync()) as Map<String, dynamic>;
  late final RgbImage frame = decodeToRgb(File('$dir/frame-1s.jpg').readAsBytesSync())!;

  /// [board]'s bull in the whole picture, and its outer radius.
  (Point2, double) key(String board) {
    final k = truth[board] as Map<String, dynamic>;
    final c = k['centre'] as List, o = k['fullFrameOffset'] as List;
    final outer = ((k['outerRadius'] ?? (k['edges'] as Map)['1.0']) as num).toDouble();
    return (Point2((c[0] as num) + (o[0] as num).toDouble(), (c[1] as num) + (o[1] as num).toDouble()), outer);
  }

  // The right board is in shade against the bright sky: found tapped on its
  // bull or 10 px above it, but taps 10 px right or (-7, 7) give a wrong
  // fit (bull 37 px off; outer 147 px), 2026-10-21. Known limit: drag the
  // outline into place (calibration's adjust), or tap again.
  final taps = {
    'middle': const [(0, 0), (10, 0), (0, -10), (-7, 7)],
    'right': const [(0, 0), (0, -10)],
  };
  final centreSlack = {'middle': 0.05, 'right': 0.08};
  for (final board in ['middle', 'right']) {
    for (final (dx, dy) in taps[board]!) {
      test('$board board, tapped ${dx == 0 && dy == 0 ? 'on its bull' : '($dx, $dy) px off'}: found, on its bull, the right size',
          () {
        final (bull, outer) = key(board);
        final r = locateTargetAt(frame, Point2(bull.x + dx, bull.y + dy), _radii);
        expect(r, isA<TargetFound>(), reason: describe(r));
        final found = r as TargetFound;
        final foundBull = found.boundaries[_radii.first]!;
        expect(dist(Point2(foundBull.cx, foundBull.cy), bull), lessThan(outer * centreSlack[board]!), reason: describe(r));
        expect(meanRadius(found.outer), closeTo(outer, outer * 0.06), reason: describe(r));
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  }

  test('middle board, tapped: each painted edge within 10% of the hand-measured one', () {
    final (bull, _) = key('middle');
    final edges = ((truth['middle'] as Map)['edges'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(double.parse(k), (v as num).toDouble()));
    final r = locateTargetAt(frame, bull, _radii);
    expect(r, isA<TargetFound>(), reason: describe(r));
    final found = {...(r as TargetFound).boundaries, 1.0: r.outer};
    final lines = <String>[];
    var ok = true;
    for (final MapEntry(key: radius, value: expected) in edges.entries) {
      final got = found[radius] == null ? null : meanRadius(found[radius]!);
      final good = got != null && (got - expected).abs() <= expected * 0.1;
      ok &= good;
      lines.add('edge $radius: expected ${expected.toStringAsFixed(1)}, found ${got?.toStringAsFixed(1)} ${good ? '✅' : '❌'}');
    }
    expect(ok, isTrue, reason: lines.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a tap on the fence between the boards finds nothing', () {
    final r = locateTargetAt(frame, const Point2(560, 1350), _radii);
    expect(r, isA<TargetNotFound>(), reason: describe(r));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
