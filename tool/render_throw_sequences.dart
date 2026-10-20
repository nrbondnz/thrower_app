// Renders short camera-stream sequences of throws on the reference board, as
// the phone sees them from 2 m beside the board (45°), with known answers:
// a knife sticking (twice), a knife bouncing off, and someone retrieving the
// knives. Test data for throw detection (story-checkpoint-throw-detection).
//
//   dart run tool/render_throw_sequences.dart [<sequence name> ...]
//
// Output: docs/thrower/reference/sequences/<name>/
//   frame-NNN.jpg  15 fps, 640 × 360 (half the 1280 × 720 stream), with
//                  motion blur (1/60 s shutter) and sensor noise
//   before.jpg, after.jpg  full stream resolution (1280 × 720), settled
//   preview.gif    for watching
//   truth.json     per-frame phase and the event's answer

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:thrower_app/vision/synthetic_scene.dart';

import 'reference_board.dart';
import 'throw_scenes.dart';

const outDir = 'docs/thrower/reference/sequences';

const knife1 = StuckKnife(u: 0.18, v: 0.27, pitchDegrees: 18, yawDegrees: -6);
const knife2 = StuckKnife(u: -0.45, v: -0.38, pitchDegrees: -22, yawDegrees: 9);
const bounceAt = StuckKnife(u: 0.05, v: -0.12, pitchDegrees: 5, yawDegrees: 3);

void main(List<String> args) {
  stdout.writeln('Building the board texture from the reference photo…');
  final board = ReferenceBoard.build();
  targetRadius = board.targetRadius;
  final sequences = [
    stick('throw-stick-ring4', before: const [], knife: knife1),
    stick('throw-stick-ring3', before: const [knife1], knife: knife2),
    bounce('throw-bounce-out', before: const [knife1, knife2], at: bounceAt),
    retrieval('retrieve-knives', stuck: const [knife1, knife2]),
  ];
  for (final seq in sequences) {
    if (args.isNotEmpty && !args.contains(seq.name)) continue;
    _render(seq, board);
  }
}

// The scenes (stick, bounce, retrieval) and the frame rendering are in
// throw_scenes.dart, shared with render_game.dart.

void _render(Sequence seq, ReferenceBoard board) {
  final dir = Directory('$outDir/${seq.name}')..createSync(recursive: true);
  for (final f in dir.listSync()) {
    f.deleteSync();
  }
  final stopwatch = Stopwatch()..start();
  final frames = (seq.duration * fps).round();
  final phases = <String>[];
  final gif = img.GifEncoder(repeat: 0);
  for (var i = 0; i < frames; i++) {
    final t = i / fps;
    final moment = seq.at(t);
    phases.add(moment.phase);
    // Motion blur: average several instants across the shutter when moving.
    final frame = withNoise(blurredFrame(seq.at, t, board), seed: i + seq.name.hashCode);
    saveJpg(frame, '${dir.path}/frame-${i.toString().padLeft(3, '0')}.jpg', quality: 88);
    gif.addFrame(toImage(frame, scale: 0.5), duration: (100 / fps).round());
    stdout.write('\r${seq.name}: frame ${i + 1}/$frames');
  }
  File('${dir.path}/preview.gif').writeAsBytesSync(gif.finish()!);

  // Settled before/after at full stream resolution, with the knives' answers.
  final before = sceneAt(seq.at(0), board, width: fullWidth, height: fullHeight, supersample: 2).render();
  final after = sceneAt(seq.at(seq.duration - 1e-6), board, width: fullWidth, height: fullHeight, supersample: 2).render();
  saveJpg(before.image, '${dir.path}/before.jpg');
  saveJpg(after.image, '${dir.path}/after.jpg');

  final knivesAfter = [
    for (final k in after.knives)
      {
        'entryNormalised': [k.knife.u, k.knife.v],
        'entryPixelFull': [k.entryPixel.x.round(), k.entryPixel.y.round()],
        'entryPixelFrame': [(k.entryPixel.x / 2).round(), (k.entryPixel.y / 2).round()],
        'score': k.score,
      },
  ];
  final truth = {
    'fps': fps,
    'frameSize': [frameWidth, frameHeight],
    'fullSize': [fullWidth, fullHeight],
    'camera': {'x': camera.x, 'y': camera.y, 'z': camera.z},
    'paintedRingRadii': board.paintedRingRadii,
    'event': seq.event,
    'stuckKnivesAfter': knivesAfter,
    'phases': phases,
  };
  File('${dir.path}/truth.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(truth));
  stdout.writeln('\r${seq.name}: $frames frames in ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(0)} s');
}
