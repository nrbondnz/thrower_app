// Runs the ring locator on a photo and writes a copy with the fitted ellipses
// drawn on it, to check results by eye.
//
//   dart run tool/locate_target.dart <photo> [<output.png>]

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/vision/colour_ring_locator.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/target_locator.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/locate_target.dart <photo> [<output.png>]');
    exit(64);
  }
  final input = args[0];
  final output = args.length > 1 ? args[1] : '${input.replaceFirst(RegExp(r'\.\w+$'), '')}-located.png';

  final decoded = img.decodeImage(File(input).readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Could not decode $input');
    exit(1);
  }
  final rgb = RgbImage.blank(decoded.width, decoded.height);
  for (final p in decoded) {
    rgb.setPixel(p.x, p.y, p.r.toInt(), p.g.toInt(), p.b.toInt());
  }

  final model = TargetModel.ikthof();
  final locator = ColourRingLocator(boundaryRadii: [for (final r in model.rings.take(model.rings.length - 1)) r.outerRadius]);
  final stopwatch = Stopwatch()..start();
  final result = locator.locate(rgb);
  stdout.writeln('Located in ${stopwatch.elapsedMilliseconds} ms');

  switch (result) {
    case TargetNotFound(:final reason, :final attempted, :final attemptedPoints):
      stdout.writeln('Not found: $reason');
      for (final e in attempted.entries) {
        stdout.writeln('  attempted r=${e.key}: ${e.value}  (${attemptedPoints[e.key]!.length} points)');
      }
      for (final points in attemptedPoints.values) {
        for (final p in points) {
          img.fillCircle(decoded, x: p.x.round(), y: p.y.round(), radius: 3, color: img.ColorRgb8(255, 255, 0));
        }
      }
      for (final e in attempted.values) {
        _drawEllipse(decoded, e, img.ColorRgb8(255, 0, 255));
      }
    case TargetFound(:final boundaries, :final outer, :final confidence, :final boundaryPoints):
      stdout.writeln('Confidence ${confidence.toStringAsFixed(2)}');
      for (final e in boundaries.entries) {
        stdout.writeln('  r=${e.key}: ${e.value}  (${boundaryPoints[e.key]!.length} points)');
      }
      stdout.writeln('  outer: $outer');
      for (final points in boundaryPoints.values) {
        for (final p in points) {
          img.fillCircle(decoded, x: p.x.round(), y: p.y.round(), radius: 3, color: img.ColorRgb8(255, 255, 0));
        }
      }
      for (final e in [...boundaries.values, outer]) {
        _drawEllipse(decoded, e, img.ColorRgb8(0, 120, 255));
      }
  }
  File(output).writeAsBytesSync(img.encodePng(decoded));
  stdout.writeln('Wrote $output');
}

void _drawEllipse(img.Image image, Ellipse e, img.Color colour) {
  const steps = 720;
  for (var i = 0; i < steps; i++) {
    final a = e.pointAt(2 * 3.141592653589793 * i / steps);
    final b = e.pointAt(2 * 3.141592653589793 * (i + 1) / steps);
    img.drawLine(image, x1: a.x.round(), y1: a.y.round(), x2: b.x.round(), y2: b.y.round(), color: colour, thickness: 2);
  }
}
