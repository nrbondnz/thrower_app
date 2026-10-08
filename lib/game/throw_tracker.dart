import '../vision/motion_detector.dart';
import '../vision/target_calibration.dart';
import '../vision/throw_classifier.dart';

/// Decides what each settled episode was and keeps track of the knives in the
/// board (pure Dart; [ThrowWatcher] feeds it from the camera, tests feed it
/// recorded frames).
///
/// - A stuck knife is remembered with a new id and its shape.
/// - A knife that falls out is recognised by its shape and forgotten.
/// - A board visit (collecting knives) or a changed scene forgets them all.
class ThrowTracker {
  ThrowTracker(this.calibration);

  final TargetCalibration calibration;
  final _knives = <(int, NewObject)>[];
  var _nextId = 0;

  /// Ids of the knives currently in the board.
  List<int> get knifeIds => [for (final (id, _) in _knives) id];

  /// The outcome of [episode], and the knife it concerns: a new id for a
  /// stuck knife, or the id of the knife that fell out.
  (ThrowOutcome, int?) onEpisode(MotionEpisode episode) {
    final outcome = classifyThrow(episode, calibration, knownKnives: [for (final (_, shape) in _knives) shape]);
    switch (outcome.kind) {
      case ThrowOutcomeKind.stuck:
        final id = _nextId++;
        _knives.add((id, outcome.object!));
        return (outcome, id);
      case ThrowOutcomeKind.fellOut:
        final (id, _) = _knives.removeAt(outcome.knownKnifeIndex!);
        return (outcome, id);
      case ThrowOutcomeKind.boardVisit:
      case ThrowOutcomeKind.sceneChanged:
        _knives.clear();
        return (outcome, null);
      case ThrowOutcomeKind.bounceOut:
        return (outcome, null);
    }
  }
}
