import 'dart:math' as math;

import 'board_shape.dart';
import 'ellipse.dart';
import 'image_difference.dart';
import 'luma_image.dart';
import 'target_calibration.dart';

/// The part of the image to watch, as fractions of its width and height (so
/// it doesn't depend on how far frames are downscaled).
class WatchRegion {
  const WatchRegion(this.left, this.top, this.right, this.bottom, {this.target});

  /// The board around a locked calibration: its edge's bounding box
  /// ([TargetCalibration.shape]), grown by [margin] about its centre for knife
  /// handles sticking out (a stuck knife reaches ~0.5 of the target radius
  /// beyond its entry point).
  factory WatchRegion.fromCalibration(TargetCalibration c, {double margin = 1.5}) {
    final shape = c.shape, centre = shape.centre;
    final (:halfWidth, :halfHeight) = shape.halfExtent;
    final halfW = halfWidth * margin, halfH = halfHeight * margin;
    double fx(double x) => (x / c.imageWidth).clamp(0.0, 1.0);
    double fy(double y) => (y / c.imageHeight).clamp(0.0, 1.0);
    return WatchRegion(fx(centre.x - halfW), fy(centre.y - halfH), fx(centre.x + halfW), fy(centre.y + halfH),
        target: shape.rescaled(1 / c.imageWidth));
  }

  final double left;
  final double top;
  final double right;
  final double bottom;

  /// The board's edge, in fractions of the image's **width** (both axes), or
  /// null if unknown: then every shape counts as on the target.
  final BoardShape? target;
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
    this.peakArea,
    this.impact,
    this.impactFrame,
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

  /// The frame with the largest moving shape on the target, and its number:
  /// where a knife hits, the board jolts and the knife stops at once. Null if
  /// nothing moved on the target, or not measured. Quick draw times throws
  /// by it. Not [start]: seen from behind the thrower, a knife in flight is
  /// over the board's face all the way in, so motion starts frames before it
  /// arrives. On the Quick draw clip at 60 fps, motion started 1 and 7 frames
  /// before the answer key's impact frames, the first shape on the target
  /// 1 and 5 before, and the largest was on them (2026-10-14).
  final Duration? impact;
  final int? impactFrame;
  final Duration start;
  final Duration settled;
  final double peakChange;

  /// The largest connected shape **touching the target** that changed between
  /// two frames during the episode, sized as [MotionUpdate.shape]: a knife
  /// flying in or bouncing off makes one; a refocusing camera only scattered
  /// specks, and people moving at the edge of the picture shapes that don't
  /// touch the target. Null if not measured (hand-made episodes in tests).
  final double? peakShape;

  /// The largest connected shape anywhere that changed between two frames
  /// during the episode, as a share of the region's **area**: a person is a
  /// big blob (4%+ of the region on both the 140 px and the full-resolution
  /// Live test recordings), a knife and the board's jolt at most ~1%. Null if
  /// not measured.
  final double? peakArea;

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
  const MotionUpdate(this.state, this.changed, {this.shape = 0, this.finished, this.fromBefore});

  final WatchState state;

  /// Share of the region that changed since the previous frame.
  final double changed;

  /// The largest connected shape that changed since the previous frame (what
  /// starts and ends motion): its pixels ÷ the region's side, i.e. the
  /// length of a 1 px wide streak in region sides. Measured in length, not
  /// area, because a knife is thin: on a board twice the size (more pixels,
  /// a closer or zoomed camera) its streak has twice the pixels, while the
  /// region has four times as many.
  final double shape;

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
    this.startSize = 0.12,
    this.stillSize = 0.06,
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

  /// How big ([MotionUpdate.shape]) the largest changed shape must be to
  /// start an episode: 12 px in a 100 × 100 region, 33 px in the Live test's
  /// 277 × 277. One blurred knife frame is more: 20+ px at 126 × 126 on the
  /// 140 px copy of the recordings, where compression specks stayed ≤ 12.
  /// (Until 2026-10-12 this was 0.1% of the region's area, which grew too
  /// fast for the full-resolution recordings: a bounce-out's 39 px streak
  /// fell short of 77.)
  final double startSize;

  /// While the largest changed shape is smaller than this, a frame counts as
  /// still.
  final double stillSize;
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
  var _peakArea = 0.0;
  var _wasBlocked = false;
  Duration? _impact;
  int? _impactFrame;

  /// Notes the frame with the largest moving shape on the target so far.
  /// Call before `_peakShape` takes this frame in.
  void _noteImpact(_Difference difference, Duration time) {
    if (difference.onTarget >= startSize && (_impact == null || difference.onTarget > _peakShape)) {
      _impact = time;
      _impactFrame = _frame;
    }
  }

  WatchState get state => _state;

  /// Starts afresh from the next frame, as if it were the first: any
  /// episode under way is dropped, and that frame becomes the reference.
  /// The learned noise is kept. Used after watching was paused (score
  /// corrections: a hand at the phone isn't a throw).
  void restart() {
    _previous = null;
    _state = WatchState.watching;
    _startFrame = _start = _stillSince = _impact = _impactFrame = null;
    _peak = _peakShape = _peakArea = 0;
    _wasBlocked = false;
  }

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
        if (moving < stillSize && quietMean != null) {
          _noise = 0.9 * _noise + 0.1 * (quietMean / 1.13);
          // Follow slow changes (light drifting) while nothing is happening.
          _reference = image;
        }
        if (moving >= startSize) {
          _state = WatchState.motion;
          _startFrame = _frame;
          _start = time;
          _peak = changed;
          _peakShape = difference.onTarget;
          _peakArea = difference.largestArea;
          _impact = _impactFrame = null;
          _noteImpact(difference, time);
        }
      case WatchState.motion:
        _peak = math.max(_peak, changed);
        _noteImpact(difference, time);
        _peakShape = math.max(_peakShape, difference.onTarget);
        _peakArea = math.max(_peakArea, difference.largestArea);
        if (moving < stillSize) {
          _state = WatchState.settling;
          _stillSince = time;
        }
      case WatchState.settling:
      case WatchState.blocked:
        if (moving >= stillSize) {
          _peak = math.max(_peak, changed);
          _noteImpact(difference, time);
          _peakShape = math.max(_peakShape, difference.onTarget);
          _peakArea = math.max(_peakArea, difference.largestArea);
          _state = WatchState.motion;
        } else if (time - _stillSince! >= settleTime) {
          final settledDifference = _difference(image, _reference ?? image);
          final fromBefore = settledDifference.changed;
          final stillFor = time - _stillSince!;
          if (fromBefore > blockedFraction && stillFor < maxBlocked) {
            _state = WatchState.blocked;
            _wasBlocked = true;
            return MotionUpdate(_state, changed, shape: moving, fromBefore: fromBefore);
          }
          final episode = MotionEpisode(
            startFrame: _startFrame!,
            settledFrame: _frame,
            start: _start!,
            settled: time,
            peakChange: _peak,
            peakShape: _peakShape,
            peakArea: _peakArea,
            impact: _impact,
            impactFrame: _impactFrame,
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
          return MotionUpdate(_state, changed, shape: moving, finished: episode, fromBefore: fromBefore);
        }
    }
    return MotionUpdate(_state, changed, shape: moving);
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
    if (w <= 0 || h <= 0) return const _Difference(0, 0, 0, 0, null, 0);
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
    final target = region.target?.rescaled(a.width.toDouble());
    final (largest, onTarget) = largestShapes(changed, w, h,
        touching: target == null
            ? null
            : (i) => target.reach(Point2((x0 + i % w).toDouble(), (y0 + i ~/ w).toDouble())) <= 1.05);
    final side = math.sqrt(total);
    return _Difference(
      changedCount / total,
      largest / side,
      largest / total,
      onTarget / side,
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
  const _Difference(this.changed, this.largest, this.largestArea, this.onTarget, this.quietMean, this.sigma);

  /// Share of the region that changed.
  final double changed;

  /// The largest connected changed shape, as [MotionUpdate.shape].
  final double largest;

  /// The same shape as a share of the region's area.
  final double largestArea;

  /// The largest connected changed shape touching the target, as
  /// [MotionUpdate.shape].
  final double onTarget;

  /// Mean |difference| of the unchanged pixels (null if none), for the noise
  /// estimate.
  final double? quietMean;

  /// The pair's noise ([MotionDetector.pairNoise]).
  final double sigma;
}
