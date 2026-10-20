// Shared by the render tools (render_throw_sequences.dart, render_game.dart):
// the throwing scenes as functions of time (a knife sticking, a knife
// bouncing off, someone collecting the knives), and turning a moment into a
// camera frame (motion blur, sensor noise).

import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/synthetic_scene.dart';

import 'reference_board.dart';

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

/// The board's size, for placing knives: set once from the reference board.
late double targetRadius;

// --- Sequences ---------------------------------------------------------------

/// When a stick's knife lands, and when its handle stops wobbling, from the
/// sequence's start.
const stickImpact = 1.05, stickSettled = stickImpact + 0.3, stickDuration = 2.0;

/// Settled → knife flies in (visible only for its last ~1.2 m) → sticks →
/// handle wobbles → settled.
Sequence stick(String name, {required List<StuckKnife> before, required StuckKnife knife}) {
  const impact = stickImpact, wobbleEnd = stickSettled, duration = stickDuration;
  return Sequence(
    name,
    duration,
    (t) {
      if (t < impact - flightTime) return Moment(stuck: before, phase: 'settled');
      if (t < impact) return Moment(stuck: before, flying: [inFlight(knife, t - (impact - flightTime))], phase: 'motion');
      if (t < wobbleEnd) {
        final s = t - impact;
        final wobble = 4 * math.exp(-s / 0.1) * math.cos(2 * math.pi * 9 * s);
        final shaking = StuckKnife(
            u: knife.u, v: knife.v, pitchDegrees: knife.pitchDegrees + wobble, yawDegrees: knife.yawDegrees);
        return Moment(stuck: [...before, shaking], phase: 'motion');
      }
      return Moment(stuck: [...before, knife], phase: 'settled');
    },
    {'type': 'stick', 'impactSeconds': impact, 'settledSeconds': wobbleEnd, 'knife': knifeJson(knife)},
  );
}

const bounceImpact = 1.05, bounceDuration = 2.6;

/// Settled → knife flies in handle-first → bounces back and falls to the grass
/// (below the frame from a camera at board height). [lying] knives already on
/// the grass (earlier bounce-outs) stay there.
Sequence bounce(String name, {required List<StuckKnife> before, required StuckKnife at, List<FlyingKnife> lying = const []}) {
  const impact = bounceImpact, duration = bounceDuration;
  final out = outDirection(at);
  // Handle-first: the knife arrives turned half a revolution from sticking.
  final arrivalCentre = onBoard(at) + out * (knifeLength / 2 + 0.01);
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
      if (t < impact - flightTime) return Moment(stuck: before, flying: lying, phase: 'settled');
      if (t < impact) {
        final k = inFlight(at, t - (impact - flightTime), handleFirst: true);
        return Moment(stuck: before, flying: [...lying, k], phase: 'motion');
      }
      final s = t - impact;
      if (s < fall) {
        final centre = arrivalCentre +
            Vec3(bounceVelocity.x * s, bounceVelocity.y * s - 0.5 * gravity * s * s, bounceVelocity.z * s);
        final d = rotate(out * -1, spinAxis, -2 * math.pi * 3 * s);
        return Moment(
          stuck: before,
          flying: [...lying, FlyingKnife(tip: centre - d * (knifeLength / 2), direction: d, spinAxis: spinAxis)],
          phase: 'motion',
        );
      }
      final landed = FlyingKnife(
        tip: rest - restDirection * (knifeLength / 2),
        direction: restDirection,
        spinAxis: const Vec3(0, 1, 0),
      );
      return Moment(stuck: before, flying: [...lying, landed], phase: s < fall + 0.15 ? 'motion' : 'settled');
    },
    {
      'type': 'bounceOut',
      'impactSeconds': impact,
      'hitNormalised': [at.u, at.v],
      'note': 'The knife bounces back and falls below the bottom of the frame (from a camera at board height, the ground in front of the board is out of view). Nothing new is left on the target: scores 0.',
    },
  );
}

/// The knife a [bounce] leaves on the grass, once settled.
FlyingKnife bouncedKnife(StuckKnife at) {
  final b = bounce('', before: const [], at: at);
  return b.at(b.duration).flying.last;
}

const retrievalArrives = 0.4, retrievalPulled = 2.9, retrievalGone = 5.4, retrievalDuration = 6.0;

/// Settled → the thrower walks up from the line, stands at the board while
/// pulling the knives out, walks back → settled, empty board. [lying]
/// knives (bounce-outs on the grass) are picked up with them.
Sequence retrieval(String name, {required List<StuckKnife> stuck, List<FlyingKnife> lying = const []}) {
  const walkIn = (retrievalArrives, 2.0), stand = (2.0, 3.8), walkOut = (3.8, retrievalGone), duration = retrievalDuration;
  const from = Vec3(0.35, 0, 3.2), atBoard = Vec3(0.2, 0, 0.42);
  const pulled = retrievalPulled;
  Vec3 lerp(Vec3 a, Vec3 b, double s) => a + (b - a) * s;
  return Sequence(
    name,
    duration,
    (t) {
      final knives = t < pulled ? stuck : const <StuckKnife>[];
      final grass = t < pulled ? lying : const <FlyingKnife>[];
      if (t < walkIn.$1) return Moment(stuck: knives, flying: grass, phase: 'settled');
      if (t < walkIn.$2) {
        final s = (t - walkIn.$1) / (walkIn.$2 - walkIn.$1);
        return Moment(stuck: knives, flying: grass, people: [Person(lerp(from, atBoard, s))], phase: 'person');
      }
      if (t < stand.$2) return Moment(stuck: knives, flying: grass, people: const [Person(atBoard)], phase: 'person');
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

const knifeLength = SyntheticScene.embeddedLength + SyntheticScene.bladeLength + SyntheticScene.handleLength;

Vec3 onBoard(StuckKnife k) => Vec3(k.u * targetRadius, k.v * targetRadius, 0);

Vec3 outDirection(StuckKnife k) {
  final pitch = k.pitchDegrees * math.pi / 180, yaw = k.yawDegrees * math.pi / 180;
  return Vec3(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch)).normalised;
}

/// The knife [s] seconds after release, flying to stick as [k] (one full
/// spin over the flight), or to arrive handle-first for a bounce.
FlyingKnife inFlight(StuckKnife k, double s, {bool handleFirst = false}) {
  final endDir = handleFirst ? outDirection(k) * -1 : outDirection(k);
  final endTip = handleFirst
      ? onBoard(k) + outDirection(k) * (knifeLength + 0.01)
      : onBoard(k) - endDir * SyntheticScene.embeddedLength;
  final endCentre = endTip + endDir * (knifeLength / 2);
  final p = s / flightTime;
  // Straight line plus a ballistic sag (zero at both ends).
  final sag = 0.5 * gravity * s * (flightTime - s);
  final centre = release + (endCentre - release) * p - Vec3(0, sag, 0);
  const spinAxis = Vec3(1, 0, 0);
  final d = rotate(endDir, spinAxis, -2 * math.pi * (1 - p));
  return FlyingKnife(tip: centre - d * (knifeLength / 2), direction: d, spinAxis: spinAxis);
}

/// [v] rotated by [angle] about unit [axis] (Rodrigues).
Vec3 rotate(Vec3 v, Vec3 axis, double angle) {
  final c = math.cos(angle), s = math.sin(angle);
  return v * c + axis.cross(v) * s + axis * (axis.dot(v) * (1 - c));
}

Map<String, Object> knifeJson(StuckKnife k) =>
    {'entryNormalised': [k.u, k.v], 'pitchDegrees': k.pitchDegrees, 'yawDegrees': k.yawDegrees};

// --- Rendering -----------------------------------------------------------------

SyntheticScene sceneAt(Moment m, ReferenceBoard board, {required int width, required int height, int supersample = 1}) =>
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

/// The frame at [t] in [at] without noise: the average of several instants
/// across the shutter when something moves ([samples] of them), as RGB
/// bytes.
List<double> blurredFrame(Moment Function(double t) at, double t, ReferenceBoard board, {int samples = blurSamples}) {
  final moving = at(t).moving;
  final n = moving ? samples : 1;
  final acc = List<double>.filled(frameWidth * frameHeight * 3, 0);
  for (var k = 0; k < n; k++) {
    final tk = n == 1 ? t : t + shutter * (k / (n - 1) - 0.5);
    final rendered = sceneAt(at(tk), board, width: frameWidth, height: frameHeight).render().image;
    for (var j = 0; j < acc.length; j++) {
      acc[j] += rendered.pixels[j];
    }
  }
  for (var j = 0; j < acc.length; j++) {
    acc[j] /= n;
  }
  return acc;
}

/// [mean] (an averaged frame) with sensor noise added, [seed] fixing it.
RgbImage withNoise(List<double> mean, {required int seed}) {
  final random = math.Random(seed);
  final out = RgbImage.blank(frameWidth, frameHeight);
  for (var j = 0; j < mean.length; j++) {
    // Box–Muller.
    final g = math.sqrt(-2 * math.log(1 - random.nextDouble())) * math.cos(2 * math.pi * random.nextDouble());
    out.pixels[j] = (mean[j] + g * noiseSigma).round().clamp(0, 255);
  }
  return out;
}

img.Image toImage(RgbImage rgb, {double scale = 1}) {
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
