import 'rgb_image.dart';
import 'target_locator.dart';

/// Runs [inner] on the image as it is, and only if that doesn't find the
/// target, again on a contrast-stretched copy: the darkest [clip] of
/// brightness becomes black and the brightest [clip] white, with the same
/// linear map on all three channels so hues are kept.
///
/// The ring finder needs the two ring colours to differ by a fixed amount
/// (`ColourRingLocator.edgeContrast`). Indoors, the camera's live stream is
/// washed out: on Nigel's A4 test (2026-10-08) the frame was found at 97%, but
/// the same frame at half brightness or half contrast was not found at all;
/// stretched, both are found (93% / 97%). Stretching is a fallback, not the
/// default, because it also boosts non-target contrast (white paper on a grey
/// wall), which made the finder pick the paper when the target was cut off by
/// the frame edge. Run on the close-up crop too, it adapts to the board's light.
class ContrastNormalisingLocator implements TargetLocator {
  ContrastNormalisingLocator(this.inner, {this.clip = 0.01});

  final TargetLocator inner;
  final double clip;

  @override
  TargetLocateResult locate(RgbImage image) {
    final asIs = inner.locate(image);
    if (asIs is TargetFound) return asIs;
    final stretched = normaliseContrast(image, clip: clip);
    if (identical(stretched, image)) return asIs;
    final second = inner.locate(stretched);
    if (second is TargetFound) return second;
    // Neither found it: keep whichever gave an attempt to look closer at.
    return asIs is TargetNotFound && asIs.attempted.isEmpty ? second : asIs;
  }
}

/// [image] with brightness stretched so its [clip] and 1 − [clip] percentiles
/// land on 0 and 255. Returns [image] unchanged if it's already full range or
/// flat.
RgbImage normaliseContrast(RgbImage image, {double clip = 0.01}) {
  final p = image.pixels;
  final histogram = List<int>.filled(256, 0);
  for (var i = 0; i < p.length; i += 3) {
    histogram[(p[i] * 77 + p[i + 1] * 150 + p[i + 2] * 29) >> 8]++;
  }
  final total = p.length ~/ 3;
  final cut = (total * clip).round();
  var low = 0, seen = 0;
  while (low < 255 && seen + histogram[low] <= cut) {
    seen += histogram[low++];
  }
  var high = 255;
  seen = 0;
  while (high > 0 && seen + histogram[high] <= cut) {
    seen += histogram[high--];
  }
  if (high - low < 8 || (low == 0 && high == 255)) return image;

  final scale = 255 / (high - low);
  final lut = [for (var v = 0; v < 256; v++) ((v - low) * scale).round().clamp(0, 255)];
  final out = RgbImage.blank(image.width, image.height);
  final o = out.pixels;
  for (var i = 0; i < p.length; i++) {
    o[i] = lut[p[i]];
  }
  return out;
}
