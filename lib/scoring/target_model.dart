import 'dart:math' as math;

/// A point on the target face in normalised coordinates: the centre is (0, 0)
/// and the outer edge of the outermost scoring ring has radius 1.
///
/// The vision layer converts image pixels into this space; scoring never sees
/// pixels.
class TargetPoint {
  const TargetPoint(this.x, this.y);

  final double x;
  final double y;

  double get distanceFromCentre => math.sqrt(x * x + y * y);

  @override
  String toString() => 'TargetPoint($x, $y)';
}

/// How a blade that touches the line between two rings is scored.
///
/// The sports disagree (see Design Decisions → Throwing Sport): IKTHOF awards
/// the higher ring, WATL the lower. IATF's "majority of the blade" rule needs
/// the blade's extent, so it is left for the scoring-by-hit-point backlog item.
enum LineTouchRule { higher, lower }

/// One scoring ring: everything inside [outerRadius] (normalised) that is not
/// inside a smaller ring scores [score].
class Ring {
  const Ring({required this.outerRadius, required this.score});

  final double outerRadius;
  final int score;
}

/// Maps a [TargetPoint] to a score.
class TargetModel {
  TargetModel({required List<Ring> rings, this.lineTouchRule = LineTouchRule.higher})
      : rings = List.unmodifiable([...rings]..sort((a, b) => a.outerRadius.compareTo(b.outerRadius)));

  /// IKTHOF layout: rings 10 / 20 / 30 / 40 / 50 cm in diameter, scoring
  /// 5 / 4 / 3 / 2 / 1 from the centre outwards.
  factory TargetModel.ikthof({LineTouchRule lineTouchRule = LineTouchRule.higher}) => TargetModel(
        rings: const [
          Ring(outerRadius: 0.2, score: 5),
          Ring(outerRadius: 0.4, score: 4),
          Ring(outerRadius: 0.6, score: 3),
          Ring(outerRadius: 0.8, score: 2),
          Ring(outerRadius: 1.0, score: 1),
        ],
        lineTouchRule: lineTouchRule,
      );

  /// Rings ordered from the centre outwards.
  final List<Ring> rings;
  final LineTouchRule lineTouchRule;

  /// Score for a blade that meets the target at [point].
  ///
  /// [bladeHalfWidth] (normalised) is how far the blade reaches either side of
  /// [point]. A blade touching a line, or lying exactly on it, counts as
  /// touching both rings, and [lineTouchRule] picks which one scores. Returns 0
  /// outside the outermost ring.
  int scoreAt(TargetPoint point, {double bladeHalfWidth = 0}) {
    final r = point.distanceFromCentre;
    for (final ring in rings) {
      final inRing = switch (lineTouchRule) {
        LineTouchRule.higher => r - bladeHalfWidth <= ring.outerRadius,
        LineTouchRule.lower => r + bladeHalfWidth < ring.outerRadius,
      };
      if (inRing) return ring.score;
    }
    return 0;
  }
}
