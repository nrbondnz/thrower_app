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

import 'package:thrower_app/vision/coarse_to_fine_locator.dart';
import 'package:thrower_app/vision/synthetic_scene.dart';
import 'package:thrower_app/vision/target_locator.dart';

import 'reference_board.dart';

const outDir = 'docs/thrower/reference/camera-views';

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
  stdout.writeln('Building the board texture from the reference photo…');
  final board = ReferenceBoard.build();
  saveJpg(board.texture.cleaned, '$outDir/board-face-knives-removed.jpg');
  if (args.contains('--texture-only')) return;

  final painted = board.paintedRingRadii, boundaries = board.boundaries;
  stdout.writeln('Painted ring edges (normalised): ${[for (final r in painted) r.toStringAsFixed(3)].join(', ')}');
  stdout.writeln('Board ${boardDiameterMetres * 100} cm across → outer ring '
      '${(board.targetRadius * 200).toStringAsFixed(1)} cm across');

  final truth = <String, Object>{
    'camera': {'x': camera.x, 'y': camera.y, 'z': camera.z, 'note': 'metres; board face at z=0, x = thrower\'s right'},
    'boardDiameterMetres': boardDiameterMetres,
    'targetRadiusMetres': board.targetRadius,
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
        texture: board.texture,
        ringRadii: painted,
        targetRadius: board.targetRadius,
      );
      final rendered = scene.render();
      saveJpg(rendered.image, '$outDir/$file');

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
