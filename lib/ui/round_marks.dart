import '../game/throw_watcher.dart';
import '../vision/ellipse.dart';
import '../vision/throw_classifier.dart';

/// What the Play screen marks for the round in progress (Nigel, 2026-10-11):
/// a yellow circle with its score where each stuck knife went in, and a "0"
/// beside the board for each throw that scored nothing without a place to
/// show it (a bounce-out, or a stuck knife whose entry wasn't found). All
/// cleared when the knives are collected or the next round starts.
class RoundMarks {
  /// Stuck knives still in the board: knife id → (entry, score).
  final knives = <int, (Point2, int)>{};

  /// Labels shown beside the board, in throw order.
  final beside = <String>[];

  bool get isEmpty => knives.isEmpty && beside.isEmpty;

  void clear() {
    knives.clear();
    beside.clear();
  }

  /// Applies [event]; [score] is what the game recorded for it,
  /// [newRound] whether it started a new round (the last one was complete).
  void apply(ThrowEvent event, {required int score, required bool newRound}) {
    switch (event.outcome.kind) {
      case ThrowOutcomeKind.stuck:
        if (newRound) clear();
        if (event.entry case final entry?) {
          knives[event.knifeId!] = (entry.point, score);
        } else {
          beside.add('0');
        }
      case ThrowOutcomeKind.bounceOut:
        if (newRound) clear();
        beside.add('0');
      case ThrowOutcomeKind.fellOut:
        // It scores 0 now: its circle moves beside the board.
        if (knives.remove(event.knifeId) != null) beside.add('0');
      case ThrowOutcomeKind.boardVisit:
        clear();
      case ThrowOutcomeKind.sceneChanged:
      case ThrowOutcomeKind.nothing:
        break;
    }
  }
}

/// Where the [index]th "beside the board" mark goes, in image pixels: a
/// column just right of the outer ring, from level with its top, or left of
/// it if there's no room on the right ([imageWidth]). [radius] is the
/// mark's radius in image pixels.
Point2 besidePosition(Ellipse outer, int index, {required int imageWidth, required double radius}) {
  final reach = outer.semiMajor;
  final step = radius * 2.4;
  final right = outer.cx + reach + radius * 1.5;
  final x = right + radius <= imageWidth ? right : outer.cx - reach - radius * 1.5;
  return Point2(x, outer.cy - reach + radius + index * step);
}
