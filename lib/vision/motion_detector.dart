import 'dart:math' as math;

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
    this.before,
    this.after,
    this.threshold = 12,
  });

  /// True if, while settling, something stood in front of the board for a
  /// while (someone at the board).
  final bool wasBlocked;

  /// The settled board just before the episode and just after it.
  final LumaImage? before;
  final LumaImage? after;

  /// The changed-pixel threshold in use (brightness levels).
  final int threshold;

  final int startFrame;
  final int settledFrame;
  final Duration start;
  final Duration settled;
  final double peakChange;

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
  const MotionUpdate(this.state, this.changed, {this.finished});

  final WatchState state;

  /// Share of the region that changed since the previous frame.
  final double changed;

  /// Set on the frame an episode settles.
  final MotionEpisode? finished;
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
    this.startFraction = 0.002,
    this.stillFraction = 0.0008,
    this.settleTime = const Duration(milliseconds: 300),
    this.minThreshold = 12,
    this.noiseFactor = 6,
    this.blockedFraction = 0.08,
    this.maxBlocked = const Duration(seconds: 5),
  });

  /// More than this share of the region differing from the reference means
  /// something is in the way (a knife changes ~1–2%; a person ~25% here).
  final double blockedFraction;
  final Duration maxBlocked;

  final WatchRegion region;

  /// Share of the region that must change to start an episode (at 320 px,
  /// about 20 pixels of a 100 × 100 region: one blurred knife frame is more).
  final double startFraction;

  /// Below this share, a frame counts as still.
  final double stillFraction;
  final Duration settleTime;
  final int minThreshold;
  final double noiseFactor;

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

    final (changed, quietMean) = _difference(image, previous);

    switch (_state) {
      case WatchState.watching:
        // Learn the noise from still frames: the mean |difference| of two
        // noisy frames is ≈ 1.13 σ.
        if (changed < stillFraction && quietMean != null) {
          _noise = 0.9 * _noise + 0.1 * (quietMean / 1.13);
          // Follow slow changes (light drifting) while nothing is happening.
          _reference = image;
        }
        if (changed >= startFraction) {
          _state = WatchState.motion;
          _startFrame = _frame;
          _start = time;
          _peak = changed;
        }
      case WatchState.motion:
        _peak = math.max(_peak, changed);
        if (changed < stillFraction) {
          _state = WatchState.settling;
          _stillSince = time;
        }
      case WatchState.settling:
      case WatchState.blocked:
        if (changed >= stillFraction) {
          _peak = math.max(_peak, changed);
          _state = WatchState.motion;
        } else if (time - _stillSince! >= settleTime) {
          final fromBefore = _difference(image, _reference ?? image).$1;
          final stillFor = time - _stillSince!;
          if (fromBefore > blockedFraction && stillFor < maxBlocked) {
            _state = WatchState.blocked;
            _wasBlocked = true;
            return MotionUpdate(_state, changed);
          }
          final episode = MotionEpisode(
            startFrame: _startFrame!,
            settledFrame: _frame,
            start: _start!,
            settled: time,
            peakChange: _peak,
            changeFromBefore: fromBefore,
            acceptedNewScene: fromBefore > blockedFraction,
            wasBlocked: _wasBlocked,
            before: _reference,
            after: image,
            threshold: threshold,
          );
          _wasBlocked = false;
          _state = WatchState.watching;
          _reference = image;
          return MotionUpdate(_state, changed, finished: episode);
        }
    }
    return MotionUpdate(_state, changed);
  }

  /// Share of the region where [a] and [b] differ by more than [threshold],
  /// and the mean |difference| of the pixels that don't (null if none).
  (double, double?) _difference(LumaImage a, LumaImage b) {
    final x0 = (region.left * a.width).floor(), x1 = (region.right * a.width).ceil();
    final y0 = (region.top * a.height).floor(), y1 = (region.bottom * a.height).ceil();
    final limit = threshold;
    var changedCount = 0, total = 0, quietSum = 0, quietCount = 0;
    for (var y = y0; y < y1; y++) {
      final row = y * a.width;
      for (var x = x0; x < x1; x++) {
        final d = (a.pixels[row + x] - b.pixels[row + x]).abs();
        total++;
        if (d > limit) {
          changedCount++;
        } else {
          quietSum += d;
          quietCount++;
        }
      }
    }
    return (total == 0 ? 0.0 : changedCount / total, quietCount == 0 ? null : quietSum / quietCount);
  }
}
