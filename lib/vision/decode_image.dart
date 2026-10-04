import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'rgb_image.dart';

/// Decodes a JPEG or PNG into an [RgbImage], or returns null if it can't.
RgbImage? decodeToRgb(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final rgb = RgbImage.blank(decoded.width, decoded.height);
  for (final p in decoded) {
    rgb.setPixel(p.x, p.y, p.r.toInt(), p.g.toInt(), p.b.toInt());
  }
  return rgb;
}
