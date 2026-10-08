import 'dart:typed_data';

/// An 8-bit RGB image, row-major, 3 bytes per pixel. The vision layer's only
/// image type: camera frames and decoded photos are converted to it at the edges.
class RgbImage {
  RgbImage(this.width, this.height, this.pixels) : assert(pixels.length == width * height * 3);

  RgbImage.blank(this.width, this.height) : pixels = Uint8List(width * height * 3);

  final int width;
  final int height;
  final Uint8List pixels;

  int _offset(int x, int y) => (y * width + x) * 3;

  bool contains(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  int red(int x, int y) => pixels[_offset(x, y)];
  int green(int x, int y) => pixels[_offset(x, y) + 1];
  int blue(int x, int y) => pixels[_offset(x, y) + 2];

  void setPixel(int x, int y, int r, int g, int b) {
    final o = _offset(x, y);
    pixels[o] = r;
    pixels[o + 1] = g;
    pixels[o + 2] = b;
  }

  /// The [w] × [h] region whose top-left corner is ([x], [y]); must lie inside.
  RgbImage crop(int x, int y, int w, int h) {
    final out = RgbImage.blank(w, h);
    for (var row = 0; row < h; row++) {
      final from = _offset(x, y + row);
      out.pixels.setRange(row * w * 3, (row + 1) * w * 3, pixels, from);
    }
    return out;
  }

  /// Nearest-neighbour downscale so the longer side is at most [maxSide].
  /// Returns this image unchanged if it is already small enough.
  RgbImage downscaled(int maxSide) {
    final longest = width > height ? width : height;
    if (longest <= maxSide) return this;
    final scale = maxSide / longest;
    final w = (width * scale).round();
    final h = (height * scale).round();
    final out = RgbImage.blank(w, h);
    for (var y = 0; y < h; y++) {
      final sy = (y / scale).floor().clamp(0, height - 1);
      for (var x = 0; x < w; x++) {
        final sx = (x / scale).floor().clamp(0, width - 1);
        final o = _offset(sx, sy);
        out.setPixel(x, y, pixels[o], pixels[o + 1], pixels[o + 2]);
      }
    }
    return out;
  }
}
