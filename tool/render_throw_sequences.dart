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
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/synthetic_scene.dart';

import 'reference_board.dart';

const outDir = 'docs/thrower/reference/sequences';
const fps = 15;
const frameWidth = 640, frameHeight = 360;
const fullWidth = 1280, fullHeight = 720;
const fov = 66.0;

/// Shutter 1/60 s: motion blur from this many instants across it.
const blurSamples = 4;
const shutter = 1 / 60;
const noiseSigma = 2.5;

/// Thrower's release point: 4 m out, a little above the board's centre.
const release = Vec3(0, 0.25, 4.0);
const flightTime = 0.45;
const gravity = 9.8;

const knife1 = StuckKnife(u: 0.18, v: 0.27, pitchDegrees: 18, yawDegrees: -6);
const knife2 = StuckKnife(u: -0.45, v: -0.38, pitchDegrees: -22, yawDegrees: 9);
const bounceAt = StuckKnife(u: 0.05, v: -0.12, pitchDegrees: 5, yawDegrees: 3);

/// What's in the scene at one instant.
class Moment {
  const Moment({this.stuck = const [], this.flying = const [], this.people = const [], required this.phase});

  final List<StuckKnife> stuck;
  final List<FlyingKnife> flying;
  final List<Person> people;

  /// 'settled' (nothing moving) or 'motion'.
  final String phase;

  bool get moving => phase != 'settled';
}

class Sequence {
  const Sequence(this.name, this.duration, this.at, this.event);

  final String name;
  final double duration;
  final Moment Function(double t) at;
  final Map<String, Object> event;
}

void main(List<String> args) {
  stdout.writeln('Building the board texture from the reference photo…');
  final board = ReferenceBoard.build();
  _targetRadius = board.targetRadius;
  final sequences = [
    _stick('throw-stick-ring4', before: const [], knife: knife1),
    _stick('throw-stick-ring3', before: const [knife1], knife: knife2),
    _bounce('throw-bounce-out', before: const [knife1, knife2], at: bounceAt),
    _retrieval('retrieve-knives', stuck: const [knife1, knife2]),
  ];
  for (final seq in sequences) {
    if (args.isNotEmpty && !args.contains(seq.name)) continue;
    _render(seq, board);
  }
}

// --- Sequences ---------------------------------------------------------------

/// Settled → knife flies in (visible only for its last ~1.2 m) → sticks →
/// handle wobbles → settled.
Sequence _stick(String name, {required List<StuckKnife> before, required StuckKnife knife}) {
  const impact = 1.05, wobbleEnd = impact + 0.3, duration = 2.0;
  return Sequence(
    name,
    duration,
    (t) {
      if (t < impact - flightTime) return Moment(stuck: before, phase: 'settled');
      if (t < impact) return Moment(stuck: before, flying: [_inFlight(knife, t - (impact - flightTime))], phase: 'motion');
      if (t < wobbleEnd) {
        final s = t - impact;
        final wobble = 4 * math.exp(-s / 0.1) * math.cos(2 * math.pi * 9 * s);
        final shaking = StuckKnife(
            u: knife.u, v: knife.v, pitchDegrees: knife.pitchDegrees + wobble, yawDegrees: knife.yawDegrees);
        return Moment(stuck: [...before, shaking], phase: 'motion');
      }
      return Moment(stuck: [...before, knife], phase: 'settled');
    },
    {'type': 'stick', 'impactSeconds': impact, 'settledSeconds': wobbleEnd, 'knife': _knifeJson(knife)},
  );
}

/// Settled → knife flies in handle-first → bounces back and falls to the grass
/// (below the frame from a camera at board height).
Sequence _bounce(String name, {required List<StuckKnife> before, required StuckKnife at}) {
  const impact = 1.05, duration = 2.6;
  final out = _outDirection(at);
  // Handle-first: the knife arrives turned half a revolution from sticking.
  final arrivalCentre = _onBoard(at) + out * (_knifeLength / 2 + 0.01);
  final spinAxis = const Vec3(1, 0, 0);
  const bounceVelocity = Vec3(0.35, 0.9, 1.5);
  // Time for the centre to fall to just above the ground.
  final restY = SyntheticScene.groundY + 0.012;
  final drop = arrivalCentre.y - restY;
  final fall = (bounceVelocity.y + math.sqrt(bounceVelocity.y * bounceVelocity.y + 2 * gravity * drop)) / gravity;
  final rest = arrivalCentre +
      Vec3(bounceVelocity.x * fall, -(arrivalCentre.y - restY), bounceVelocity.z * fall);
  const restDirection = Vec3(0.85, 0, 0.53);

  return Sequence(
    name,
    duration,
    (t) {
      if (t < impact - flightTime) return Moment(stuck: before, phase: 'settled');
      if (t < impact) {
        final k = _inFlight(at, t - (impact - flightTime), handleFirst: true);
        return Moment(stuck: before, flying: [k], phase: 'motion');
      }
      final s = t - impact;
      if (s < fall) {
        final centre = arrivalCentre +
            Vec3(bounceVelocity.x * s, bounceVelocity.y * s - 0.5 * gravity * s * s, bounceVelocity.z * s);
        final d = _rotate(out * -1, spinAxis, -2 * math.pi * 3 * s);
        return Moment(
          stuck: before,
          flying: [FlyingKnife(tip: centre - d * (_knifeLength / 2), direction: d, spinAxis: spinAxis)],
          phase: 'motion',
        );
      }
      final lying = FlyingKnife(
        tip: rest - restDirection * (_knifeLength / 2),
        direction: restDirection,
        spinAxis: const Vec3(0, 1, 0),
      );
      return Moment(stuck: before, flying: [lying], phase: s < fall + 0.15 ? 'motion' : 'settled');
    },
    {
      'type': 'bounceOut',
      'impactSeconds': impact,
      'hitNormalised': [at.u, at.v],
      'note': 'The knife bounces back and falls below the bottom of the frame (from a camera at board height, the ground in front of the board is out of view). Nothing new is left on the target: scores 0.',
    },
  );
}

/// Settled → the thrower walks up from the line, stands at the board while
/// pulling the knives out, walks back → settled, empty board.
Sequence _retrieval(String name, {required List<StuckKnife> stuck}) {
  const walkIn = (0.4, 2.0), stand = (2.0, 3.8), walkOut = (3.8, 5.4), duration = 6.0;
  const from = Vec3(0.35, 0, 3.2), atBoard = Vec3(0.2, 0, 0.42);
  const pulled = 2.9;
  Vec3 lerp(Vec3 a, Vec3 b, double s) => a + (b - a) * s;
  return Sequence(
    name,
    duration,
    (t) {
      final knives = t < pulled ? stuck : const <StuckKnife>[];
      if (t < walkIn.$1) return Moment(stuck: knives, phase: 'settled');
      if (t < walkIn.$2) {
        final s = (t - walkIn.$1) / (walkIn.$2 - walkIn.$1);
        return Moment(stuck: knives, people: [Person(lerp(from, atBoard, s))], phase: 'person');
      }
      if (t < stand.$2) return Moment(stuck: knives, people: const [Person(atBoard)], phase: 'person');
      if (t < walkOut.$2) {
        final s = (t - walkOut.$1) / (walkOut.$2 - walkOut.$1);
        return Moment(people: [Person(lerp(atBoard, from, s))], phase: 'person');
      }
      return const Moment(phase: 'settled');
    },
    {
      'type': 'retrieval',
      'personArrivesSeconds': walkIn.$1,
      'knivesPulledSeconds': pulled,
      'personGoneSeconds': walkOut.$2,
      'knivesRemoved': stuck.length,
    },
  );
}

// --- Knife flight --------------------------------------------------------------

const _knifeLength = SyntheticScene.embeddedLength + SyntheticScene.bladeLength + SyntheticScene.handleLength;
late double _targetRadius;

Vec3 _onBoard(StuckKnife k) => Vec3(k.u * _targetRadius, k.v * _targetRadius, 0);

Vec3 _outDirection(StuckKnife k) {
  final pitch = k.pitchDegrees * math.pi / 180, yaw = k.yawDegrees * math.pi / 180;
  return Vec3(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)).normalised;
}

/// The knife [s] seconds after release, flying to stick as [k] (one full
/// spin over the flight), or to arrive handle-first for a bounce.
FlyingKnife _inFlight(StuckKnife k, double s, {bool handleFirst = false}) {
  final endDir = handleFirst ? _outDirection(k) * -1 : _outDirection(k);
  final endTip = handleFirst
      ? _onBoard(k) + _outDirection(k) * (_knifeLength + 0.01)
      : _onBoard(k) - endDir * SyntheticScene.embeddedLength;
  final endCentre = endTip + endDir * (_knifeLength / 2);
  final p = s / flightTime;
  // Straight line plus a ballistic sag (zero at both ends).
  final sag = 0.5 * gravity * s * (flightTime - s);
  final centre = release + (endCentre - release) * p - Vec3(0, sag, 0);
  const spinAxis = Vec3(1, 0, 0);
  final d = _rotate(endDir, spinAxis, -2 * math.pi * (1 - p));
  return FlyingKnife(tip: centre - d * (_knifeLength / 2), direction: d, spinAxis: spinAxis);
}

/// [v] rotated by [angle] about unit [axis] (Rodrigues).
Vec3 _rotate(Vec3 v, Vec3 axis, double angle) {
  final c = math.cos(angle), s = math.sin(angle);
  return v * c + axis.cross(v) * s + axis * (axis.dot(v) * (1 - c));
}

Map<String, Object> _knifeJson(StuckKnife k) =>
    {'entryNormalised': [k.u, k.v], 'pitchDegrees': k.pitchDegrees, 'yawDegrees': k.yawDegrees};

// --- Rendering -----------------------------------------------------------------

SyntheticScene _scene(Moment m, ReferenceBoard board, {required int width, required int height, int supersample = 1}) =>
    SyntheticScene(
      width: width,
      height: height,
      cameraPosition: camera,
      horizontalFovDegrees: fov,
      knives: m.stuck,
      flyingKnives: m.flying,
      people: m.people,
      texture: board.texture,
      ringRadii: board.paintedRingRadii,
      targetRadius: board.targetRadius,
      supersample: supersample,
    );

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
    final samples = moment.moving ? blurSamples : 1;
    final acc = List<double>.filled(frameWidth * frameHeight * 3, 0);
    for (var k = 0; k < samples; k++) {
      final tk = samples == 1 ? t : t + shutter * (k / (samples - 1) - 0.5);
      final rendered = _scene(seq.at(tk), board, width: frameWidth, height: frameHeight).render().image;
      for (var j = 0; j < acc.length; j++) {
        acc[j] += rendered.pixels[j];
      }
    }
    final frame = _withNoise(acc, samples, seed: i + seq.name.hashCode);
    saveJpg(frame, '${dir.path}/frame-${i.toString().padLeft(3, '0')}.jpg', quality: 88);
    gif.addFrame(_toImage(frame, scale: 0.5), duration: (100 / fps).round());
    stdout.write('\r${seq.name}: frame ${i + 1}/$frames');
  }
  File('${dir.path}/preview.gif').writeAsBytesSync(gif.finish()!);

  // Settled before/after at full stream resolution, with the knives' answers.
  final before = _scene(seq.at(0), board, width: fullWidth, height: fullHeight, supersample: 2).render();
  final after = _scene(seq.at(seq.duration - 1e-6), board, width: fullWidth, height: fullHeight, supersample: 2).render();
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

RgbImage _withNoise(List<double> acc, int samples, {required int seed}) {
  final random = math.Random(seed);
  final out = RgbImage.blank(frameWidth, frameHeight);
  for (var j = 0; j < acc.length; j++) {
    // Box–Muller.
    final g = math.sqrt(-2 * math.log(1 - random.nextDouble())) * math.cos(2 * math.pi * random.nextDouble());
    out.pixels[j] = (acc[j] / samples + g * noiseSigma).round().clamp(0, 255);
  }
  return out;
}

img.Image _toImage(RgbImage rgb, {double scale = 1}) {
  final w = (rgb.width * scale).round(), h = (rgb.height * scale).round();
  final out = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final sx = (x / scale).floor(), sy = (y / scale).floor();
      out.setPixelRgb(x, y, rgb.red(sx, sy), rgb.green(sx, sy), rgb.blue(sx, sy));
    }
  }
  return out;
}
