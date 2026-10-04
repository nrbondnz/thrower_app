import 'package:flutter/material.dart';

import '../scoring/target_model.dart';

const targetRed = Color(0xFFC62828);
const targetWood = Color(0xFFE3C9A0);

/// Draws [model]'s rings, alternating red and bare wood with a red bull (as in
/// docs/thrower/reference/target-example.png), plus an optional hit marker.
class TargetPainter extends CustomPainter {
  TargetPainter({required this.model, this.hit, this.markerRadius = 0});

  final TargetModel model;

  /// Hit position in normalised target coordinates.
  final TargetPoint? hit;

  /// Marker radius, normalised (the blade's half-width).
  final double markerRadius;

  /// Pixel radius of normalised radius 1 for a canvas of [size].
  static double scaleFor(Size size) => size.shortestSide / 2 * 0.9;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final scale = scaleFor(size);

    // Outermost ring first so smaller rings paint over it; the bull is red.
    final outwards = model.rings;
    for (var i = outwards.length - 1; i >= 0; i--) {
      final colour = i.isEven ? targetRed : targetWood;
      canvas.drawCircle(centre, outwards[i].outerRadius * scale, Paint()..color = colour);
    }

    final hit = this.hit;
    if (hit != null) {
      final at = centre + Offset(hit.x, hit.y) * scale;
      canvas.drawCircle(at, markerRadius * scale, Paint()..color = Colors.black54);
      canvas.drawCircle(at, 3, Paint()..color = Colors.black);
    }
  }

  @override
  bool shouldRepaint(TargetPainter oldDelegate) =>
      oldDelegate.model != model || oldDelegate.hit != hit || oldDelegate.markerRadius != markerRadius;
}
