import 'dart:math' as math;

import 'image_difference.dart';
import 'luma_image.dart';
import 'target_calibration.dart';

/// The part of the image to watch, as fractions of its width and height (so
/// it doesn't depend on how far frames are downscaled).
class WatchRegion {
  const WatchRegion(this.left, this.top, this.right, this.bottom);

  /// The board around a locked calibration: the outer ring's bounding box,
  /// grown by [margin] about its centre for knife handles sticking out (a
  /// stuck knife reaches ~0.5 of the target radius beyond its entry point).
  factory WatchRegion.fromCalibration(TargetCalibration c, {double margin = 1.5}) {
    final e = c.outer;
    final cos = math.cos(e.angle), sin = math.sin(e.angle);
    final halfW = math.sqrt(math.pow(e.semiMajor * cos, 2) + math.pow(e.semiMinor * sin, 2)) * margin;
    final halfH = math.sqrt(math.pow(e.semiMajor * sin, 2) + math.pow(e.semiMinor * cos, 2)) * margin;
    double fx(double x) => (x / c.imageWidth).clamp(0.0, 1.0);
    double fy(double y) => (y / c.imageHeight).clamp(0.0, 1.0);
    return WatchRegion(fx(e.cx - halfW), fy(e.cy - halfH), fx(e.cx + halfW), fy(e.cy + halfH));
  }

  final double left;
  final double top;
  final double right;
  final double bottom;
}

enum WatchState {
  /// The board is still; waiting for something to happen.
  watching,

  /// Something in the region is changing between frames.
  motion,

  /// It has stopped changing; waiting to be sure it has settled.
  settling,

  /// It has stopped changing but doesn't look like the board did: something
  /// (usually a person at the board) is in the way. Waiting for it to clear.
  blocked,
}

/// One stretch of motion that has settled again: a throw, a bounce-out, or
/// someone at the board. [peakChange] is the largest share of the region that
/// changed between two frames (a person covers far more than a knife).
class MotionEpisode {
  const MotionEpisode({
    required this.startFrame,
    required this.settledFrame,
    required this.start,
    required this.settled,
    required this.peakChange,
    required this.changeFromBefore,
    this.acceptedNewScene = false,
    this.wasBlocked = false,
    this.peakShape,
    this.before,
    this.after,
    this.threshold = 12,
    int? visitThreshold,
  }) : visitThreshold = visitThreshold ?? threshold;

  /// True if, while settling, something stood in front of the board for a
  /// while (someone at the board).
  final bool wasBlocked;

  /// The settled board just before the episode and just after it.
  final LumaImage? before;
  final LumaImage? after;

  /// The changed-pixel threshold for comparing [before] and [after]
  /// (brightness levels).
  final int threshold;

  /// A stricter threshold for the same comparison after a board visit, when
  /// marks left by collecting knives mustn't look like a placed knife.
  final int visitThreshold;

  final int startFrame;
  final int settledFrame;
  final Duration start;
  final Duration settled;
  final double peakChange;

  /// The largest connected shape that changed between two frames during the
  /// episode, as a share of the region: a flying knife makes a compact shape,
  /// a refocusing camera only scattered specks, a person a huge one. Null if
  /// not measured (hand-made episodes in tests).
  final double? peakShape;

  /// Share of the region that differs from how it looked before the episode
  /// (a new knife: ~1–2%; knives removed: a few %).
  final double changeFromBefore;

  /// True if the view stayed different but still for so long that it was
  /// accepted as the new normal (e.g. lights switched on) rather than "blocked".
  final bool acceptedNewScene;

  @override
  String toString() => 'MotionEpisode(frames $startFrame–$settledFrame, peak ${(peakChange * 100).toStringAsFixed(1)}%, '
      'from before ${(changeFromBefore * 100).toStringAsFixed(1)}%${acceptedNewScene ? ', new scene' : ''})';
}

class MotionUpdate {
  const MotionUpdate(this.state, this.changed, {this.finished, this.fromBefore});

  final WatchState state;

  /// Share of the region that changed since the previous frame.
  final double changed;

  /// Set on the frame an episode settles.
  final MotionEpisode? finished;

  /// When the region was still long enough to check: the share that differs
  /// from the reference (above blockedFraction means blocked). For debugging.
  final double? fromBefore;
}

/// Watches a region of a stream of brightness frames for motion, and reports
/// each episode once the region has been still for [settleTime] **and looks
/// like the board again**.
///
/// A pixel counts as changed when it differs from the previous frame by more
/// than [noiseFactor] × the estimated sensor noise (never less than
/// [minThreshold]). The noise is learned while watching, so a dim, noisy
/// indoor stream doesn't look like constant motion.
///
/// "Still" isn't enough: someone standing still at the board stops the frames
/// changing (the rendered retrieval did exactly that). So the detector keeps a
/// reference frame of the last settled board and only reports "settled" when
/// less than [blockedFraction] of the region differs from it; otherwise it's
/// [WatchState.blocked]. After [maxBlocked] of being still but different, the
/// view is accepted as the new normal (flagged on the episode).
class MotionDetector {
  MotionDetector(
    this.region, {
    this.startFraction = 0.001,
    this.stillFraction = 0.0005,
    this.settleTime = const Duration(milliseconds: 300),
    this.minThreshold = 12,
    this.noiseFactor = 6,
    this.pairNoiseFactor = 5,
    this.settledNoiseFactor = 3.5,
    this.blockedFraction = 0.08,
    this.maxBlocked = const Duration(seconds: 5),
  });

  /// More than this share of the region differing from the reference means
  /// something is in the way (a knife changes ~1–2%; a person ~25% here).
  final double blockedFraction;
  final Duration maxBlocked;

  final WatchRegion region;

  /// Share of the region the largest changed shape must cover to start an
  /// episode (at 320 px, about 10 pixels of a 100 × 100 region; 16 of the
  /// Live test's 126 × 126: one blurred knife frame is more).
  final double startFraction;

  /// While the largest changed shape is below this share, a frame counts as
  /// still.
  final double stillFraction;
  final Duration settleTime;

  /// The smallest brightness difference that counts as a change: the frame
  /// source's `TargetCamera.minChange` (12 for the live camera; 20 for the
  /// Live test's compressed recordings, whose re-encoded blocks differ by up
  /// to ~20 levels).
  final int minThreshold;
  final double noiseFactor;

  /// See [pairNoise].
  final double pairNoiseFactor;

  /// Like [pairNoiseFactor], for the threshold an episode's settled board is
  /// compared with the board before it at ([MotionEpisode.threshold]): lower,
  /// because both are still frames, so only re-encoding separates them, and
  /// a head-on knife is small. On the Live test recordings, the before/after
  /// threshold at 5 × σ was 30–44 and three knives showed as 9–12 px, just
  /// under the 12.6 px a knife needs; no bounce-out left anything behind.
  final double settledNoiseFactor;

  LumaImage? _previous;

  /// The board as last seen settled.
  LumaImage? _reference;
  var _frame = -1;
  var _state = WatchState.watching;
  var _noise = 2.0; // Estimated sensor noise (σ), learned while watching.
  int? _startFrame;
  Duration? _start;
  Duration? _stillSince;
  var _peak = 0.0;
  var _peakShape = 0.0;
  var _wasBlocked = false;

  WatchState get state => _state;

  /// The current changed-pixel threshold (brightness levels).
  int get threshold => math.max(minThreshold, (noiseFactor * _noise).round());

  MotionUpdate add(LumaImage image, Duration time) {
    _frame++;
    final previous = _previous;
    _previous = image;
    if (previous == null || previous.width != image.width || previous.height != image.height) {
      _reference = image;
      return MotionUpdate(_state, 0);
    }

    final difference = _difference(image, previous);
    final changed = difference.changed;
    // Motion is judged on the largest connected changed shape, not on the
    // total: a knife is one compact shape, while compressed video re-encodes
    // scattered blocks (up to ~12 px at 140 px on the Live test recordings,
    // against 20+ for every real throw).
    final moving = difference.largest;
    final quietMean = difference.quietMean;

    switch (_state) {
      case WatchState.watching:
        // Learn the noise from still frames: the mean |difference| of two
        // noisy frames is ≈ 1.13 σ.
        if (moving < stillFraction && quietMean != null) {
          _noise = 0.9 * _noise + 0.1 * (quietMean / 1.13);
          // Follow slow changes (light drifting) while nothing is happening.
          _reference = image;
        }
        if (moving >= startFraction) {
          _state = WatchState.motion;
          _startFrame = _frame;
          _start = time;
          _peak = changed;
          _peakShape = moving;
        }
      case WatchState.motion:
        _peak = math.max(_peak, changed);
        _peakShape = math.max(_peakShape, moving);
        if (moving < stillFraction) {
          _state = WatchState.settling;
          _stillSince = time;
        }
      case WatchState.settling:
      case WatchState.blocked:
        if (moving >= stillFraction) {
          _peak = math.max(_peak, changed);
          _peakShape = math.max(_peakShape, moving);
          _state = WatchState.motion;
        } else if (time - _stillSince! >= settleTime) {
          final settledDifference = _difference(image, _reference ?? image);
          final fromBefore = settledDifference.changed;
          final stillFor = time - _stillSince!;
          if (fromBefore > blockedFraction && stillFor < maxBlocked) {
            _state = WatchState.blocked;
            _wasBlocked = true;
            return MotionUpdate(_state, changed, fromBefore: fromBefore);
          }
          final episode = MotionEpisode(
            startFrame: _startFrame!,
            settledFrame: _frame,
            start: _start!,
            settled: time,
            peakChange: _peak,
            peakShape: _peakShape,
            changeFromBefore: fromBefore,
            acceptedNewScene: fromBefore > blockedFraction,
            wasBlocked: _wasBlocked,
            before: _reference,
            after: image,
            threshold: math.max(threshold, (settledNoiseFactor * settledDifference.sigma).round()),
            visitThreshold: math.max(threshold, (pairNoiseFactor * settledDifference.sigma).round()),
          );
          _wasBlocked = false;
          _state = WatchState.watching;
          _reference = image;
          return MotionUpdate(_state, changed, finished: episode, fromBefore: fromBefore);
        }
    }
    return MotionUpdate(_state, changed);
  }

  /// How [a] differs from [b] within the region, after re-aligning a small
  /// camera shift of up to ±3 px (see `image_difference.dart`; frame to frame
  /// too: a nudge of 2 px between two frames would otherwise start an episode
  /// that settles as a false bounce-out). A pixel has changed if it passes
  /// [lumaChanged] at the pair's threshold (see [pairNoise]).
  _Difference _difference(LumaImage a, LumaImage b) {
    final x0 = (region.left * a.width).floor(), x1 = (region.right * a.width).ceil();
    final y0 = (region.top * a.height).floor(), y1 = (region.bottom * a.height).ceil();
    final w = x1 - x0, h = y1 - y0;
    if (w <= 0 || h <= 0) return const _Difference(0, 0, null, 0);
    final area = PixelRect(x0, y0, x1, y1);
    final (dx, dy) = bestShift(a, b, area, step: 2);
    final sigma = pairNoise(a, b, area, dx: dx, dy: dy);
    final limit = math.max(threshold, (pairNoiseFactor * sigma).round());
    final changed = List<bool>.filled(w * h, false);
    var changedCount = 0, quietSum = 0, quietCount = 0;
    for (var y = y0; y < y1; y++) {
      final row = y * a.width, sy = y + dy;
      for (var x = x0; x < x1; x++) {
        final sx = x + dx;
        if (lumaChanged(a, b, x, y, limit, dx: dx, dy: dy)) {
          changed[(y - y0) * w + (x - x0)] = true;
          changedCount++;
        } else if (sx >= 0 && sy >= 0 && sx < b.width && sy < b.height) {
          quietSum += (a.pixels[row + x] - b.pixels[sy * b.width + sx]).abs();
          quietCount++;
        }
      }
    }
    final total = w * h;
    return _Difference(
      changedCount / total,
      largestShape(changed, w, h) / total,
      quietCount == 0 ? null : quietSum / quietCount,
      sigma,
    );
  }

  /// The noise (σ) between [a] and [b] (shifted by [dx], [dy]), estimated
  /// robustly from the median |difference| over [area] (σ ≈ 1.4826 ×
  /// median), so a few changed pixels (a knife) don't move it. A pixel has
  /// changed if it differs by more than the learned [threshold], raised to
  /// [pairNoiseFactor] × this pair's σ when that's higher.
  ///
  /// Why (Live test recordings, 2026-10-11): compressed video re-encodes the
  /// whole picture about once a second, shifting every pixel by a few levels
  /// (median |difference| 3–9 instead of ~0). At a fixed threshold, 1–10% of
  /// the board then "changed", and every jump became a false bounce-out. A
  /// live camera's noise is steady, so this rarely changes anything there.
  double pairNoise(LumaImage a, LumaImage b, PixelRect area, {int dx = 0, int dy = 0}) {
    final histogram = List<int>.filled(256, 0);
    var count = 0;
    for (var y = area.y0; y < area.y1; y++) {
      final sy = y + dy;
      if (sy < 0 || sy >= b.height) continue;
      for (var x = area.x0; x < area.x1; x++) {
        final sx = x + dx;
        if (sx < 0 || sx >= b.width) continue;
        histogram[(a.pixels[y * a.width + x] - b.pixels[sy * b.width + sx]).abs()]++;
        count++;
      }
    }
    var median = 0, seen = 0;
    while (median < 255) {
      seen += histogram[median];
      if (seen * 2 >= count) break;
      median++;
    }
    return 1.4826 * median;
  }
}

/// Frame-to-frame (or frame-to-reference) difference within the region.
class _Difference {
  const _Difference(this.changed, this.largest, this.quietMean, this.sigma);

  /// Share of the region that changed.
  final double changed;

  /// Share of the region covered by the largest connected changed shape.
  final double largest;

  /// Mean |difference| of the unchanged pixels (null if none), for the noise
  /// estimate.
  final double? quietMean;

  /// The pair's noise ([MotionDetector.pairNoise]).
  final double sigma;
}
