import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/game/throw_watcher.dart';
import 'package:thrower_app/ui/round_marks.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/entry_point.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/throw_classifier.dart';

const episode = MotionEpisode(
  startFrame: 0,
  settledFrame: 1,
  start: Duration.zero,
  settled: Duration(seconds: 1),
  peakChange: 0.01,
  changeFromBefore: 0.01,
);

ThrowEvent event(ThrowOutcomeKind kind, {int? id, Point2? at}) => ThrowEvent(
      ThrowOutcome(kind),
      episode,
      knifeId: id,
      entry: at == null ? null : EntryEstimate(point: at, axis: const Point2(1, 0), knifePixels: 10),
    );

void main() {
  // Marks remember which throw they are; the score is read from the game
  // when drawn (score corrections, 2026-10-17).
  const s0 = (player: 0, round: 0, index: 0);
  const s1 = (player: 0, round: 0, index: 1);

  test('a stuck knife is marked where it went in, as its throw', () {
    final marks = RoundMarks()..apply(event(ThrowOutcomeKind.stuck, id: 1, at: const Point2(10, 20)), slot: s0, newRound: false);
    expect(marks.knives[1]?.$2, s0);
    expect(marks.knives[1]?.$1.x, 10);
    expect(marks.beside, isEmpty);
  });

  test('a bounce-out is marked beside the board', () {
    final marks = RoundMarks()..apply(event(ThrowOutcomeKind.bounceOut), slot: s0, newRound: false);
    expect(marks.beside, [s0]);
  });

  test("a stuck knife whose entry wasn't found is marked beside the board", () {
    final marks = RoundMarks()..apply(event(ThrowOutcomeKind.stuck, id: 1), slot: s0, newRound: false);
    expect(marks.knives, isEmpty);
    expect(marks.beside, [s0]);
  });

  test('a knife falling out moves its mark beside the board', () {
    final marks = RoundMarks()
      ..apply(event(ThrowOutcomeKind.stuck, id: 1, at: const Point2(10, 20)), slot: s0, newRound: false)
      ..apply(event(ThrowOutcomeKind.fellOut, id: 1), newRound: false);
    expect(marks.knives, isEmpty);
    expect(marks.beside, [s0]);
  });

  test('collecting the knives clears everything', () {
    final marks = RoundMarks()
      ..apply(event(ThrowOutcomeKind.stuck, id: 1, at: const Point2(10, 20)), slot: s0, newRound: false)
      ..apply(event(ThrowOutcomeKind.bounceOut), slot: s1, newRound: false)
      ..apply(event(ThrowOutcomeKind.boardVisit), newRound: false);
    expect(marks.isEmpty, isTrue);
  });

  test("the first throw of a new round clears the last round's marks", () {
    final marks = RoundMarks()
      ..apply(event(ThrowOutcomeKind.bounceOut), slot: s0, newRound: false)
      ..apply(event(ThrowOutcomeKind.stuck, id: 2, at: const Point2(5, 5)), slot: (player: 0, round: 1, index: 0), newRound: true);
    expect(marks.beside, isEmpty);
    expect(marks.knives.keys, [2]);
  });

  test('a throw ignored by the game (no slot) leaves no mark', () {
    final marks = RoundMarks()..apply(event(ThrowOutcomeKind.bounceOut), newRound: false);
    expect(marks.isEmpty, isTrue);
  });

  test('a throw added by hand is marked beside the board; on a new round, alone', () {
    final marks = RoundMarks()
      ..apply(event(ThrowOutcomeKind.bounceOut), slot: s0, newRound: false)
      ..addByHand(s1, newRound: false);
    expect(marks.beside, [s0, s1]);
    marks.addByHand((player: 0, round: 1, index: 0), newRound: true);
    expect(marks.beside, [(player: 0, round: 1, index: 0)]);
  });

  group('besidePosition', () {
    const outer = Ellipse(cx: 50, cy: 50, semiMajor: 30, semiMinor: 30, angle: 0);

    test('a column just right of the board, from level with its top', () {
      final first = besidePosition(outer, 0, imageWidth: 200, radius: 4);
      final second = besidePosition(outer, 1, imageWidth: 200, radius: 4);
      expect(first.x, greaterThan(80));
      expect(first.y, lessThan(50));
      expect(second.x, first.x);
      expect(second.y, greaterThan(first.y + 8));
    });

    test('left of the board when there is no room on the right', () {
      expect(besidePosition(outer, 0, imageWidth: 84, radius: 4).x, lessThan(20));
    });
  });
}
