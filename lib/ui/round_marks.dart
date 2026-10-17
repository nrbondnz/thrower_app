import '../game/throw_watcher.dart';
import '../scoring/match.dart';
import '../vision/ellipse.dart';
import '../vision/throw_classifier.dart';

/// What the Play screen marks for the round in progress (Nigel, 2026-10-11):
/// a circle with its score where each stuck knife went in, and a mark
/// beside the board for each throw that has no place to show it (a
/// bounce-out, a stuck knife whose entry wasn't found, or a throw added by
/// hand). All cleared when the knives are collected or the next round
/// starts. Marks remember **which throw** they are ([ThrowSlot]), not its
/// score: the score is read from the game when they're drawn, so a score
/// changed by hand shows at once (score corrections, 2026-10-17).
class RoundMarks {
  /// Stuck knives still in the board: knife id → (entry, the throw).
  final knives = <int, (Point2, ThrowSlot)>{};

  /// Throws shown beside the board, in throw order.
  final beside = <ThrowSlot>[];

  bool get isEmpty => knives.isEmpty && beside.isEmpty;

  void clear() {
    knives.clear();
    beside.clear();
  }

  /// Applies [event]; [slot] is the throw the game recorded for it (a stuck
  /// knife or a bounce-out), [newRound] whether it started a new round (the
  /// last one was complete).
  void apply(ThrowEvent event, {ThrowSlot? slot, required bool newRound}) {
    switch (event.outcome.kind) {
      case ThrowOutcomeKind.stuck:
        if (newRound) clear();
        if (slot == null) return;
        if (event.entry case final entry?) {
          knives[event.knifeId!] = (entry.point, slot);
        } else {
          beside.add(slot);
        }
      case ThrowOutcomeKind.bounceOut:
        if (newRound) clear();
        if (slot != null) beside.add(slot);
      case ThrowOutcomeKind.fellOut:
        // It scores 0 now: its circle moves beside the board.
        if (knives.remove(event.knifeId) case (_, final slot)?) beside.add(slot);
      case ThrowOutcomeKind.boardVisit:
        clear();
      case ThrowOutcomeKind.sceneChanged:
      case ThrowOutcomeKind.nothing:
        break;
    }
  }

  /// A throw added by hand ([slot]): shown beside the board, as it has no
  /// entry point.
  void addByHand(ThrowSlot slot, {required bool newRound}) {
    if (newRound) clear();
    beside.add(slot);
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
