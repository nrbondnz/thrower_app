import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/target_locator.dart';

/// Gapped-rings story: Mark's stencilled boards (`test/fixtures/marks_boards/`),
/// whose black rings are painted in four arcs with gaps between them. Play's
/// Find target (`buildTargetLocator`) must find each board, the middle one's
/// painted edges close to the hand-measured answer key, and on the whole
/// picture (three boards, the net, the fence) the board in the middle.

const dir = 'test/fixtures/marks_boards';

/// Until the locator handles these boards (Tasks 2–4), the tests are skipped
/// with this reason; each is switched on as its fix lands.
const notYet = 'gapped-rings story: fails until Tasks 2–4 (2026-10-21: all "Rings too unclear" or a wrong fit)';

double meanRadius(Ellipse e) => (e.semiMajor + e.semiMinor) / 2;
double dist(double x1, double y1, double x2, double y2) => math.sqrt(math.pow(x1 - x2, 2) + math.pow(y1 - y2, 2));

TargetLocateResult locate(String file) {
  final model = TargetModel.katta();
  final radii = [for (final r in model.rings.take(model.rings.length - 1)) r.outerRadius];
  return buildTargetLocator(radii).locate(decodeToRgb(File('$dir/$file').readAsBytesSync())!);
}

String describe(TargetLocateResult r) => switch (r) {
      TargetFound(:final outer, :final confidence) =>
        'found at (${outer.cx.toStringAsFixed(0)}, ${outer.cy.toStringAsFixed(0)}), outer ${meanRadius(outer).toStringAsFixed(0)} px, '
            'confidence ${confidence.toStringAsFixed(2)}',
      TargetNotFound(:final reason) => 'not found: $reason',
    };

void main() {
  final truth = jsonDecode(File('$dir/truth.json').readAsStringSync()) as Map<String, dynamic>;

  for (final board in ['middle', 'left', 'right']) {
    test('$board board: found, centred on its bull, the right size', () {
      final key = truth[board] as Map<String, dynamic>;
      final (cx, cy) = ((key['centre'] as List)[0] as num, (key['centre'] as List)[1] as num);
      final outer = ((key['outerRadius'] ?? (key['edges'] as Map)['1.0']) as num).toDouble();
      final r = locate('$board.jpg');
      expect(r, isA<TargetFound>(), reason: describe(r));
      final found = (r as TargetFound).outer;
      // The bull's centre (rings aren't concentric in perspective: allow 8%).
      final bull = r.boundaries.entries.reduce((a, b) => a.key < b.key ? a : b).value;
      expect(dist(bull.cx, bull.cy, cx.toDouble(), cy.toDouble()), lessThan(outer * 0.08), reason: describe(r));
      expect(meanRadius(found), closeTo(outer, outer * 0.1), reason: describe(r));
    }, timeout: const Timeout(Duration(minutes: 2)), skip: notYet);
  }

  test('middle board: each painted edge within 7% of the hand-measured one', () {
    final key = truth['middle'] as Map<String, dynamic>;
    final edges = (key['edges'] as Map<String, dynamic>).map((k, v) => MapEntry(double.parse(k), (v as num).toDouble()));
    final r = locate('middle.jpg');
    expect(r, isA<TargetFound>(), reason: describe(r));
    final found = {...(r as TargetFound).boundaries, 1.0: r.outer};
    final lines = <String>[];
    var ok = true;
    for (final MapEntry(key: radius, value: expected) in edges.entries) {
      final e = found[radius];
      final got = e == null ? null : meanRadius(e);
      final good = got != null && (got - expected).abs() <= expected * 0.07;
      ok &= good;
      lines.add('edge $radius: expected ${expected.toStringAsFixed(1)}, found ${got?.toStringAsFixed(1)} ${good ? '✅' : '❌'}');
    }
    expect(ok, isTrue, reason: lines.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('the whole picture: Find target finds the middle board (not the net)', () {
    final key = truth['middle'] as Map<String, dynamic>;
    final offset = key['fullFrameOffset'] as List;
    final cx = ((key['centre'] as List)[0] as num) + (offset[0] as num);
    final cy = ((key['centre'] as List)[1] as num) + (offset[1] as num);
    final r = locate('frame-1s.jpg');
    expect(r, isA<TargetFound>(), reason: describe(r));
    final found = (r as TargetFound).outer;
    expect(dist(found.cx, found.cy, cx.toDouble(), cy.toDouble()), lessThan(30), reason: describe(r));
  }, timeout: const Timeout(Duration(minutes: 3)), skip: notYet);
}
