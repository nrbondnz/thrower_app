// Renders a whole game on the reference board as a Live test recording, with
// its answer key: the virtual thrower (story-checkpoint-virtual-thrower).
// The throws, bounce-outs and collections are throw_scenes.dart's, put one
// after another as a game script says.
//
//   dart run tool/render_game.dart <script.json> [<script.json> ...]
//
// A script (test/fixtures/virtual_games/<name>.json):
//   {"description": "...", "seed": 1,
//    "rounds": [[{"score": 5}, {"score": 4, "at": "outer"}, {"bounce": true}], ...]}
// Each knife: "score" 1–5 lands it in that painted ring ("at": "middle"
// (default), "inner" or "outer": a few percent from that edge, to test the
// line), at "angle" degrees round the board (default: spread by the seed);
// {"bounce": true} hits and bounces off; {"score": 0} misses the board
// (nothing seen: it isn't rendered, and the key expects no event).
// Optional per knife: "pitch", "yaw" (degrees). The knives are collected
// after every round.
//
// Output, next to the script (test/fixtures/virtual_games/<name>/):
//   game.tfrm    15 fps, 640 × 360 JPEG frames (the Live test format)
//   truth.json   the answer key: each throw's kind, time and score, and
//                each collection
//   preview.gif  a quarter-size, 5 fps preview, to watch
//
// Settled frames are rendered once per board state and reused with fresh
// noise; the moving ones are spread over the PC's cores.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:thrower_app/camera/frame_pack.dart';
import 'package:thrower_app/vision/synthetic_scene.dart';

import 'reference_board.dart';
import 'throw_scenes.dart';

/// Quiet time before the first throw (the Live test calibrates on frame 0),
/// between throws and after each collection.
const startQuiet = 2.0, gap = 1.5;

const jpegQuality = 85;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/render_game.dart <script.json> [<script.json> ...]');
    exit(64);
  }
  for (final path in args) {
    await renderGame(path);
  }
}

// --- The game timeline --------------------------------------------------------

/// One knife from the script.
class ScriptedKnife {
  ScriptedKnife.fromJson(Map<String, dynamic> j)
      : bounces = j['bounce'] == true,
        score = (j['score'] as num?)?.toInt(),
        at = (j['at'] as String?) ?? 'middle',
        angle = (j['angle'] as num?)?.toDouble(),
        pitch = (j['pitch'] as num?)?.toDouble(),
        yaw = (j['yaw'] as num?)?.toDouble();

  final bool bounces;
  final int? score;
  final String at;
  final double? angle;
  final double? pitch;
  final double? yaw;

  bool get misses => !bounces && score == 0;
}

/// A piece of the game: [seq] from [start] seconds.
class Segment {
  const Segment(this.start, this.seq);

  final double start;
  final Sequence seq;

  double get end => start + seq.duration;
}

/// The whole game as one timeline, and its answer key.
class Game {
  Game(this.segments, this.events, this.duration);

  final List<Segment> segments;
  final List<Map<String, Object>> events;
  final double duration;

  Moment at(double t) {
    for (final s in segments) {
      if (t < s.end) return s.seq.at(math.max(0, t - s.start));
    }
    return segments.last.seq.at(segments.last.seq.duration);
  }
}

/// A quiet stretch: the board as it is, nothing moving.
Sequence quiet(double duration, List<StuckKnife> stuck, List<FlyingKnife> lying) =>
    Sequence('quiet', duration, (_) => Moment(stuck: stuck, flying: lying, phase: 'settled'), const {});

/// [script] as a timeline on [board] (whose painted rings place the knives).
Game buildGame(Map<String, dynamic> script, ReferenceBoard board) {
  targetRadius = board.targetRadius;
  final random = math.Random((script['seed'] as num?)?.toInt() ?? 1);
  final rings = board.paintedRingRadii;
  final segments = <Segment>[];
  final events = <Map<String, Object>>[];
  var t = 0.0;
  void add(Sequence s) {
    segments.add(Segment(t, s));
    t += s.duration;
  }

  add(quiet(startQuiet, const [], const []));
  final rounds = (script['rounds'] as List).cast<List>();
  for (final (r, round) in rounds.indexed) {
    final stuck = <StuckKnife>[];
    final lying = <FlyingKnife>[];
    for (final (i, raw) in round.indexed) {
      final k = ScriptedKnife.fromJson(raw as Map<String, dynamic>);
      final where = {'round': r + 1, 'throw': i + 1};
      if (k.misses) {
        events.add({...where, 'kind': 'missed', 'note': 'missed the board: not rendered, nothing to see'});
        continue;
      }
      // Spread round the board, so a round's knives don't hide each other.
      final angle = (k.angle ?? (i * 120 + random.nextDouble() * 60 + r * 40)) * math.pi / 180;
      final radius = k.bounces ? 0.2 + random.nextDouble() * 0.5 : _radiusFor(k.score!, k.at, rings);
      final knife = StuckKnife(
        u: radius * math.cos(angle),
        v: radius * math.sin(angle),
        pitchDegrees: k.pitch ?? (random.nextDouble() * 36 - 18),
        yawDegrees: k.yaw ?? (random.nextDouble() * 20 - 10),
      );
      final start = t;
      if (k.bounces) {
        add(bounce('bounce', before: List.of(stuck), at: knife, lying: List.of(lying)));
        lying.add(bouncedKnife(knife));
        events.add({...where, 'kind': 'bounceOut', 'time': start + bounceImpact, 'score': 0});
      } else {
        add(stick('stick', before: List.of(stuck), knife: knife));
        stuck.add(knife);
        events.add({
          ...where,
          'kind': 'stuck',
          'time': start + stickImpact,
          'settled': start + stickSettled,
          'score': scoreOf(knife, rings),
          'entryNormalised': [knife.u, knife.v],
        });
      }
      add(quiet(gap, List.of(stuck), List.of(lying)));
    }
    final start = t;
    add(retrieval('collect', stuck: List.of(stuck), lying: List.of(lying)));
    events.add({
      'round': r + 1,
      'kind': 'visit',
      'time': start + retrievalArrives,
      'settled': start + retrievalGone,
      'knivesRemoved': stuck.length,
    });
    add(quiet(gap, const [], const []));
  }
  return Game(segments, events, t);
}

/// A radius inside painted ring [score] (5 the bull … 1 the outer):
/// its middle, or 3% of the ring's width from its inner or outer edge.
double _radiusFor(int score, String at, List<double> rings) {
  if (score < 1 || score > rings.length) throw ArgumentError('score $score');
  final outer = rings[rings.length - score];
  final inner = score == rings.length ? 0.0 : rings[rings.length - score - 1];
  final width = outer - inner;
  return switch (at) {
    // The bull has no inner edge: "inner" is near its centre.
    'inner' => score == rings.length ? 0.3 * outer : inner + 0.03 * width,
    'outer' => outer - 0.03 * width,
    _ => (inner + outer) / 2,
  };
}

/// The painted ring [knife]'s blade entered, as SyntheticScene scores it.
int scoreOf(StuckKnife knife, List<double> rings) {
  final r = math.sqrt(knife.u * knife.u + knife.v * knife.v);
  final ring = rings.indexWhere((edge) => r <= edge);
  return ring == -1 ? 0 : rings.length - ring;
}

// --- Rendering ------------------------------------------------------------------

/// What one frame needs rendered: a settled board state (shared by every
/// frame showing it), or a moving frame of its own.
typedef Job = ({String key, double t, bool moving});

String _stateKey(Moment m) => [
      for (final k in m.stuck) 's${k.u.toStringAsFixed(4)},${k.v.toStringAsFixed(4)}',
      for (final k in m.flying) 'f${k.tip.x.toStringAsFixed(3)},${k.tip.y.toStringAsFixed(3)}',
    ].join('|');

Future<void> renderGame(String scriptPath) async {
  final scriptText = File(scriptPath).readAsStringSync();
  final script = jsonDecode(scriptText) as Map<String, dynamic>;
  final name = File(scriptPath).uri.pathSegments.last.replaceAll('.json', '');
  final outDir = Directory('${File(scriptPath).parent.path}/$name')..createSync(recursive: true);
  stdout.writeln('$name: building the board…');
  final board = ReferenceBoard.build();
  final game = buildGame(script, board);
  final frames = (game.duration * fps).round();

  // Which frames share a settled render.
  final jobs = <String, Job>{};
  final frameKeys = <String>[];
  for (var i = 0; i < frames; i++) {
    final t = i / fps;
    final m = game.at(t);
    final key = m.moving ? 'frame$i' : 'state:${_stateKey(m)}';
    jobs.putIfAbsent(key, () => (key: key, t: t, moving: m.moving));
    frameKeys.add(key);
  }
  final cores = math.max(1, Platform.numberOfProcessors - 1);
  stdout.writeln('$name: ${game.duration.toStringAsFixed(1)} s, $frames frames, ${jobs.length} renders on $cores cores…');
  final stopwatch = Stopwatch()..start();

  // Spread the renders, the costly (moving) ones dealt out evenly.
  final ordered = [...jobs.values.where((j) => j.moving), ...jobs.values.where((j) => !j.moving)];
  final chunks = [for (var c = 0; c < cores; c++) <Job>[for (var i = c; i < ordered.length; i += cores) ordered[i]]];
  final results = await Future.wait([
    for (final chunk in chunks) Isolate.run(() => _renderChunk(scriptText, chunk)),
  ]);
  final means = <String, Uint8List>{for (final r in results) ...r};
  stdout.writeln('$name: rendered in ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(0)} s; encoding…');

  // Every frame: its render plus fresh noise, as the camera's sensor gives.
  final jpegs = <Uint8List>[];
  final gif = img.GifEncoder(repeat: 0);
  for (var i = 0; i < frames; i++) {
    final mean = means[frameKeys[i]]!;
    final frame = withNoise([for (final b in mean) b.toDouble()], seed: i * 7919 + name.hashCode);
    jpegs.add(img.encodeJpg(toImage(frame), quality: jpegQuality));
    if (i % 3 == 0) gif.addFrame(toImage(frame, scale: 0.25), duration: 20);
  }
  File('${outDir.path}/game.tfrm')
      .writeAsBytesSync(FramePack.build(width: frameWidth, height: frameHeight, fps: fps, jpegs: jpegs));
  File('${outDir.path}/preview.gif').writeAsBytesSync(gif.finish()!);

  final stuckScores = [for (final e in game.events) if (e['kind'] == 'stuck') e['score'] as int];
  final truth = {
    'description': script['description'] ?? '',
    'script': '$name.json',
    'fps': fps,
    'frameSize': [frameWidth, frameHeight],
    'durationSeconds': game.duration,
    'camera': {'x': camera.x, 'y': camera.y, 'z': camera.z},
    'paintedRingRadii': board.paintedRingRadii,
    'roundTotals': [
      for (var r = 1; r <= (script['rounds'] as List).length; r++)
        game.events.where((e) => e['round'] == r && e['score'] is int).fold<int>(0, (a, e) => a + (e['score'] as int)),
    ],
    'stuckScores': stuckScores,
    'events': game.events,
  };
  File('${outDir.path}/truth.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(truth));
  final mb = File('${outDir.path}/game.tfrm').lengthSync() / 1024 / 1024;
  stdout.writeln('$name: done in ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(0)} s, '
      '${mb.toStringAsFixed(1)} MB → ${outDir.path}');
}

/// Renders [jobs] of the game in [scriptText] (in a worker isolate: it builds
/// its own board and timeline). Each render is an averaged frame, as bytes.
Map<String, Uint8List> _renderChunk(String scriptText, List<Job> jobs) {
  final board = ReferenceBoard.build();
  final game = buildGame(jsonDecode(scriptText) as Map<String, dynamic>, board);
  return {
    for (final job in jobs)
      job.key: Uint8List.fromList([for (final v in blurredFrame(game.at, job.t, board)) v.round().clamp(0, 255)]),
  };
}
