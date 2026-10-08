// Renders what the phone camera sees from beside the throwing line, using the
// real board face from docs/thrower/reference/target-example.png, with 0, 1
// and 2 knives at realistic angles. Writes the images, the known answers
// (truth.json) and the ring finder's result on each.
//
//   dart run tool/render_camera_views.dart [--texture-only]
//
// --texture-only writes just board-face-knives-removed.jpg (quick check).
//
// Output: docs/thrower/reference/camera-views/.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/photo_board_texture.dart';
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/synthetic_scene.dart';
import 'package:thrower_app/vision/target_locator.dart';

const outDir = 'docs/thrower/reference/camera-views';

/// Camera 2 m to the thrower's right and 2 m out from the board, at the
/// board's height, aimed at its centre: about 45° off straight-on.
const camera = Vec3(2.0, 0.0, 2.0);

/// Nigel's boards: about 75–85 cm across (2026-10-08). The rings are sized
/// from the photo's proportions (they reach ~0.89 of the way to the bark).
const boardDiameterMetres = 0.80;

const scenes = <(String, List<StuckKnife>)>[
  ('0-knives', []),
  (
    '1-knife',
    [StuckKnife(u: 0.18, v: 0.27, pitchDegrees: 18, yawDegrees: -6)],
  ),
  (
    '2-knives',
    [
      StuckKnife(u: 0.18, v: 0.27, pitchDegrees: 18, yawDegrees: -6),
      StuckKnife(u: -0.45, v: -0.38, pitchDegrees: -22, yawDegrees: 9),
    ],
  ),
];

/// Phone main camera (about 66° across, landscape) and its 2× zoom.
const zooms = <(String, double)>[('1x', 66), ('2x', 36.1)];

void main(List<String> args) {
  Directory(outDir).createSync(recursive: true);
  final model = TargetModel.ikthof();
  final boundaries = [for (final r in model.rings.take(model.rings.length - 1)) r.outerRadius];

  stdout.writeln('Building the board texture from the reference photo…');
  final photo = decodeToRgb(File('docs/thrower/reference/target-example.png').readAsBytesSync())!;
  final fit = buildTargetLocator(boundaries).locate(photo);
  if (fit is! TargetFound) {
    stderr.writeln('Ring finder failed on the reference photo: ${(fit as TargetNotFound).reason}');
    exit(1);
  }
  // Scale per image axis from the 0.8 ring edge's extent (the photo is nearly
  // straight on, so this undoes its slight squash without rotating it).
  final edge = fit.boundaries[0.8]!;
  final c = math.cos(edge.angle), s = math.sin(edge.angle);
  final halfWidth = math.sqrt(math.pow(edge.semiMajor * c, 2) + math.pow(edge.semiMinor * s, 2));
  final halfHeight = math.sqrt(math.pow(edge.semiMajor * s, 2) + math.pow(edge.semiMinor * c, 2));
  final texture = PhotoBoardTexture(
    photo,
    centreX: edge.cx,
    centreY: edge.cy,
    pixelsPerUnitX: halfWidth / 0.8,
    pixelsPerUnitY: halfHeight / 0.8,
  );
  _save(texture.cleaned, '$outDir/board-face-knives-removed.jpg');
  if (args.contains('--texture-only')) return;

  // The board's painted rings, as measured on the photo relative to the 0.8
  // edge (hand-painted: the bull is ~0.23, not 0.2). Answers and scores use
  // these, not the ideal IKTHOF sizes.
  double meanAxis(Ellipse e) => (e.semiMajor + e.semiMinor) / 2;
  final painted = [
    for (final r in boundaries) r == 0.8 ? 0.8 : 0.8 * meanAxis(fit.boundaries[r]!) / meanAxis(edge),
    1.0,
  ];
  stdout.writeln('Painted ring edges (normalised): ${[for (final r in painted) r.toStringAsFixed(3)].join(', ')}');

  final targetRadius = boardDiameterMetres / 2 / texture.meanEdge;
  stdout.writeln('Board ${boardDiameterMetres * 100} cm across → outer ring ${(targetRadius * 200).toStringAsFixed(1)} cm across');

  final truth = <String, Object>{
    'camera': {'x': camera.x, 'y': camera.y, 'z': camera.z, 'note': 'metres; board face at z=0, x = thrower\'s right'},
    'boardDiameterMetres': boardDiameterMetres,
    'targetRadiusMetres': targetRadius,
    'paintedRingRadii': painted,
    'images': <String, Object>{},
  };

  for (final (zoomName, fov) in zooms) {
    for (final (name, knives) in scenes) {
      final file = 'view-$zoomName-$name.jpg';
      final stopwatch = Stopwatch()..start();
      final scene = SyntheticScene(
        cameraPosition: camera,
        horizontalFovDegrees: fov,
        knives: knives,
        texture: texture,
        ringRadii: painted,
        targetRadius: targetRadius,
      );
      final rendered = scene.render();
      _save(rendered.image, '$outDir/$file');

      final located = buildTargetLocator(boundaries).locate(rendered.image);
      final finder = switch (located) {
        TargetFound(:final confidence) => 'found, confidence ${(confidence * 100).round()}%',
        TargetNotFound(:final reason) => 'NOT found: $reason',
      };
      stdout.writeln('$file  rendered in ${stopwatch.elapsedMilliseconds} ms; ring finder: $finder');

      (truth['images']! as Map<String, Object>)[file] = {
        'horizontalFovDegrees': fov,
        'size': [rendered.image.width, rendered.image.height],
        'knives': [
          for (final k in rendered.knives)
            {
              'entryNormalised': [k.knife.u, k.knife.v],
              'entryPixel': [k.entryPixel.x.round(), k.entryPixel.y.round()],
              'score': k.score,
              'pitchDegrees': k.knife.pitchDegrees,
              'yawDegrees': k.knife.yawDegrees,
            },
        ],
        // Keyed by the ideal boundary (0.2 … 0.8) the ring finder reports,
        // with points on the painted edge.
        'ringEdgePixels': {
          for (var i = 0; i < boundaries.length; i++)
            '${boundaries[i]}': [for (final p in rendered.ringEdges[painted[i]]!) [p.x.round(), p.y.round()]],
        },
        'ringFinder': finder,
      };
    }
  }
  File('$outDir/truth.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(truth));
  stdout.writeln('Wrote $outDir/truth.json');
}

void _save(RgbImage rgb, String path) {
  final out = img.Image(width: rgb.width, height: rgb.height);
  for (var y = 0; y < rgb.height; y++) {
    for (var x = 0; x < rgb.width; x++) {
      out.setPixelRgb(x, y, rgb.red(x, y), rgb.green(x, y), rgb.blue(x, y));
    }
  }
  File(path).writeAsBytesSync(img.encodeJpg(out, quality: 90));
}
