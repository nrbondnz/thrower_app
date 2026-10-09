import 'dart:io';

import 'package:flutter/foundation.dart';

import '../vision/entry_point.dart';
import '../vision/luma_image.dart';
import '../vision/motion_detector.dart';
import '../vision/target_calibration.dart';
import '../vision/throw_classifier.dart';

/// Debug builds only: what the throw watcher sees, for diagnosing on a real
/// phone. Logs every state change and episode (`adb logcat | grep Watch`) and
/// saves each episode's before/after brightness frames as PGM images to the
/// app's cache, `code_cache/throw-debug/` on Android (fetch with `adb
/// exec-out run-as nz.nrbond.thrower …`), with the last [keep] episodes kept.
class WatchDebugLog {
  WatchDebugLog(this.calibration);

  final TargetCalibration calibration;
  static const keep = 20;

  WatchState? _lastState;
  var _episode = 0;

  void onUpdate(MotionUpdate update, int threshold) {
    if (!kDebugMode || update.state == _lastState) return;
    final from = update.fromBefore == null ? '' : ', differs from before ${_pct(update.fromBefore!)}';
    debugPrint('Watch: ${_lastState?.name ?? 'start'} → ${update.state.name} '
        '(changed ${_pct(update.changed)}$from, threshold $threshold)');
    _lastState = update.state;
  }

  void onEpisode(MotionEpisode e, ThrowOutcome outcome) {
    if (!kDebugMode) return;
    final n = ++_episode;
    final after = e.after;
    final needed = after == null ? null : minKnifeArea(calibration, after.width);
    debugPrint('Watch: episode $n → ${outcome.kind.name}: frames ${e.startFrame}–${e.settledFrame}, '
        'peak ${_pct(e.peakChange)}, differs from before ${_pct(e.changeFromBefore)}, '
        'blocked ${e.wasBlocked}, new scene ${e.acceptedNewScene}, threshold ${e.threshold}, '
        'new shape ${outcome.object?.area ?? 0} px (stuck needs ${needed?.toStringAsFixed(0) ?? '?'})');
    _save(n, e);
  }

  void onEntry(EntryEstimate? entry) {
    if (!kDebugMode) return;
    debugPrint(entry == null
        ? 'Watch: entry not found'
        : 'Watch: entry at (${entry.point.x.toStringAsFixed(0)}, ${entry.point.y.toStringAsFixed(0)}), '
            'knife ${entry.knifePixels} px');
  }

  Future<void> _save(int n, MotionEpisode e) async {
    try {
      final dir = Directory('${Directory.systemTemp.path}/throw-debug');
      await dir.create(recursive: true);
      final id = n.toString().padLeft(3, '0');
      if (e.before case final b?) await File('${dir.path}/ep$id-before.pgm').writeAsBytes(_pgm(b));
      if (e.after case final a?) await File('${dir.path}/ep$id-after.pgm').writeAsBytes(_pgm(a));
      final old = n - keep;
      if (old > 0) {
        final oid = old.toString().padLeft(3, '0');
        for (final suffix in ['before', 'after']) {
          final f = File('${dir.path}/ep$oid-$suffix.pgm');
          if (await f.exists()) await f.delete();
        }
      }
    } catch (error) {
      debugPrint('Watch: could not save episode frames: $error');
    }
  }

  /// A binary PGM (greyscale) image: a tiny header, then the pixels.
  static Uint8List _pgm(LumaImage img) {
    final header = 'P5\n${img.width} ${img.height}\n255\n'.codeUnits;
    return Uint8List.fromList([...header, ...img.pixels]);
  }

  static String _pct(double share) => '${(share * 100).toStringAsFixed(2)}%';
}
