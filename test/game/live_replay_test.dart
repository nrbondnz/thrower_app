import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:thrower_app/camera/camera_frame.dart';
import 'package:thrower_app/camera/frame_pack.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/game/throw_tracker.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/entry_point.dart';
import 'package:thrower_app/vision/frame_to_rgb.dart';
import 'package:thrower_app/vision/luma_image.dart';
import 'package:thrower_app/vision/motion_detector.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/target_locator.dart';
import 'package:thrower_app/vision/target_mapping.dart';
import 'package:thrower_app/vision/throw_classifier.dart';

/// Replays each Live test recording through throw detection, as Play does
/// (every frame at 15 fps is within `ThrowWatcher.interval`), and checks the
/// events against Nigel's answer key (`docs/thrower/reference/live-camera/
/// truth.json`): every throw is found as stuck or bounce-out at the right
/// time, nothing else is taken for a throw, and every collection is seen.
///
/// Each stuck knife is scored as Play scores it on a face-on board
/// ([faceOnEntry]); the footage is too coarse for every score to match (rings
/// ~8 px apart, and Nigel's own reading "is not always clear"), so there's a
/// floor on exact matches.

/// One detected episode outcome, with the score for a stuck knife.
typedef Detected = ({ThrowOutcomeKind kind, double start, double settled, int? score});

CameraFrame frameOf(FramePack pack, int i) {
  final image = img.decodeJpg(pack.jpeg(i))!;
  return CameraFrame(
    width: pack.width,
    height: pack.height,
    format: FrameFormat.bgra8888,
    planes: [FramePlane(bytes: image.getBytes(order: img.ChannelOrder.bgra), bytesPerRow: pack.width * 4, bytesPerPixel: 4)],
    timestamp: Duration(microseconds: i * 1000000 ~/ pack.fps),
  );
}

List<Detected> replay(Recording recording) {
  final pack = FramePack.parse(File(recording.asset).readAsBytesSync());
  final camera = RecordedCamera(pack, recording: recording, autoTick: false);
  final model = TargetModel.ikthof();
  final radii = [for (final r in model.rings.take(model.rings.length - 1)) r.outerRadius];
  // Calibrated on the first frame, as the Live test does.
  final found = buildTargetLocator(radii).locate(frameToRgb(frameOf(pack, 0), maxSide: 1920)!) as TargetFound;
  final calibration =
      TargetCalibration(imageWidth: pack.width, imageHeight: pack.height, boundaries: found.boundaries, outer: found.outer);
  final detector = MotionDetector(WatchRegion.fromCalibration(calibration), minThreshold: camera.minChange);
  final tracker = ThrowTracker(calibration);
  final mapping = TargetMapping(calibration);
  expect(isFaceOn(calibration), isTrue, reason: 'the recordings are filmed face on');
  final detected = <Detected>[];
  for (var i = 0; i < pack.frameCount; i++) {
    final frame = frameOf(pack, i);
    final episode = detector.add(frameToLuma(frame)!, frame.timestamp).finished;
    if (episode == null) continue;
    final (outcome, _) = tracker.onEpisode(episode);
    detected.add((
      kind: outcome.kind,
      start: episode.start.inMilliseconds / 1000,
      settled: episode.settled.inMilliseconds / 1000,
      score: outcome.kind == ThrowOutcomeKind.stuck
          ? model.scoreAt(mapping.toTarget(faceOnEntry(outcome.object!, calibration).point))
          : null,
    ));
  }
  return detected;
}

String describe(Detected d) =>
    '${d.kind.name} ${d.start.toStringAsFixed(1)}–${d.settled.toStringAsFixed(1)} s${d.score == null ? '' : ' scores ${d.score}'}';

/// Stuck knives scored exactly as Nigel did, at least (results 2026-10-11:
/// 5 of 10 and 6 of 9; all but board 1's 40.5 s and 43.2 s within a ring,
/// where the changed shape isn't where Nigel places the knife).
const exactScores = {'Target 1': 5, 'Target 2': 6};

void main() {
  final truth = jsonDecode(File('docs/thrower/reference/live-camera/truth.json').readAsStringSync()) as Map<String, dynamic>;

  for (final (index, recording) in liveTestRecordings.indexed) {
    group(recording.name, () {
      final events = (truth['board${index + 1}'] as List).cast<Map<String, dynamic>>();
      late final List<Detected> detected;
      setUpAll(() => detected = replay(recording));

      // A throw's answer-key time is within the episode, give or take [slack]
      // (times were read from the footage by eye).
      const slack = 1.0;
      bool near(Detected d, double time) => time >= d.start - slack && time <= d.settled + slack;
      ThrowOutcomeKind kindOf(Map<String, dynamic> e) =>
          e['kind'] == 'stuck' ? ThrowOutcomeKind.stuck : ThrowOutcomeKind.bounceOut;
      final throws = [for (final e in events) if (e['kind'] != 'visit') e];
      bool isThrow(Detected d) => d.kind == ThrowOutcomeKind.stuck || d.kind == ThrowOutcomeKind.bounceOut;

      test('every throw is found, as stuck or bounce-out', () {
        final missed = [
          for (final e in throws)
            if (!detected.any((d) => d.kind == kindOf(e) && near(d, (e['time'] as num).toDouble())))
              '${e['id']} (${e['kind']} at ${e['time']} s)',
        ];
        expect(missed, isEmpty, reason: 'Detected:\n${detected.map(describe).join('\n')}');
      }, timeout: const Timeout(Duration(minutes: 5)));

      test('nothing else is taken for a throw', () {
        final extra = [
          for (final d in detected)
            if (isThrow(d) && !throws.any((e) => near(d, (e['time'] as num).toDouble()))) describe(d),
        ];
        expect(extra, isEmpty);
      }, timeout: const Timeout(Duration(minutes: 5)));

      test('knives are scored as Nigel scored them, mostly', () {
        final lines = <String>[];
        var exact = 0;
        for (final e in throws.where((e) => e['kind'] == 'stuck')) {
          final d = detected.where((d) => d.kind == ThrowOutcomeKind.stuck && near(d, (e['time'] as num).toDouble())).firstOrNull;
          if (d?.score == e['score']) exact++;
          lines.add('${e['id']} at ${e['time']} s: Nigel ${e['score']}, app ${d?.score}');
        }
        expect(exact, greaterThanOrEqualTo(exactScores[recording.name]!), reason: lines.join('\n'));
      }, timeout: const Timeout(Duration(minutes: 5)));

      test("the game's rounds hold the answer key's throws (stuck or bounce-out, round by round)", () {
        var game = const GameSession();
        for (final d in detected) {
          game = switch (d.kind) {
            ThrowOutcomeKind.stuck => game.stuck(0, null),
            ThrowOutcomeKind.bounceOut => game.bounceOut(),
            ThrowOutcomeKind.boardVisit => game.boardVisited(),
            _ => game,
          };
        }
        String kinds(Iterable<String> k) => k.join(' ');
        final app = [for (final r in game.rounds) kinds(r.throws.map((t) => t.result.name))];
        final rounds = <int, List<String>>{};
        for (final e in throws) {
          (rounds[e['round'] as int] ??= []).add(e['kind'] as String);
        }
        final key = [for (final r in rounds.keys.toList()..sort()) kinds(rounds[r]!)];
        expect(app, key);
      }, timeout: const Timeout(Duration(minutes: 5)));

      // Extra visits are harmless: a visit only ends a round that has throws,
      // and every one of those is checked above.
      test('every collection of the knives is seen as a board visit', () {
        final missed = [
          for (final e in events)
            if (e['kind'] == 'visit' &&
                !detected.any((d) =>
                    d.kind == ThrowOutcomeKind.boardVisit &&
                    d.start <= (e['to'] as num) + slack &&
                    d.settled >= (e['from'] as num) - slack))
              '${e['id']} (${e['from']}–${e['to']} s)',
        ];
        expect(missed, isEmpty, reason: 'Detected:\n${detected.map(describe).join('\n')}');
      }, timeout: const Timeout(Duration(minutes: 5)));
    });
  }
}
