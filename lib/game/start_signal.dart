import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../sound/signal_sounds.dart';
import 'quick_draw_watcher.dart';

/// The pauses the start signal picks from after the 5th beep: 1.0, 1.2, …
/// 3.0 s (Nigel, 2026-10-15: "choose any 0.2 of a second between 1 and 3
/// seconds"), so the throwers can't time "go".
final startPauses = [for (var i = 0; i <= 10; i++) Duration(milliseconds: 1000 + 200 * i)];

/// When each part of one start signal happens, after Start is pressed.
class StartSchedule {
  StartSchedule(this.pause, {this.beeps = 5, this.gap = const Duration(seconds: 1)});

  /// A schedule with a pause picked at random from [startPauses].
  factory StartSchedule.random(math.Random random) => StartSchedule(startPauses[random.nextInt(startPauses.length)]);

  /// The wait between the last beep and "go".
  final Duration pause;
  final int beeps;
  final Duration gap;

  /// Beep `i` (0-based) is at `i` × [gap]: 0, 1, 2, 3, 4 s.
  List<Duration> get beepTimes => [for (var i = 0; i < beeps; i++) gap * i];

  /// "Go": the last beep, then [pause].
  Duration get go => gap * (beeps - 1) + pause;

  /// When to start watching the boards: [quickDrawLeadIn] before go.
  Duration get watchFrom => go - quickDrawLeadIn;
}

/// Where a start signal has got to.
enum StartPhase {
  /// Not started (or stopped).
  ready,

  /// The beeps, then the random pause; [StartSignal.lit] beeps so far.
  countdown,

  /// "Go" has sounded.
  go,
}

/// Runs a start signal like a Formula 1 start (Nigel and Mark, 2026-10-14):
/// 5 beeps a second apart, each lighting one of 5 lights, then a random pause
/// ([StartSchedule]), then a long "go" beep and the lights go out. It calls
/// [onWatch] 1 s before go (so the boards are analysed from then) and
/// [onGo] with the time of "go" on the camera's [clock] (the clock the frames
/// are stamped with), taken as the go beep is asked to play. The sound's
/// own start delay is the same for both throwers, so the winner is fair.
class StartSignal extends ChangeNotifier {
  StartSignal({
    required this.schedule,
    required this.sounds,
    required this.clock,
    required this.onWatch,
    required this.onGo,
  });

  final StartSchedule schedule;
  final SignalSounds sounds;
  final Duration Function() clock;
  final VoidCallback onWatch;
  final ValueChanged<Duration> onGo;

  var phase = StartPhase.ready;

  /// How many of the 5 lights are on.
  var lit = 0;

  /// "Go" on the camera's clock, once it has sounded.
  Duration? goAt;

  final _timers = <Timer>[];

  void start() {
    stop();
    phase = StartPhase.countdown;
    lit = 0;
    goAt = null;
    void light(int i) {
      lit = i + 1;
      sounds.beep();
      notifyListeners();
    }

    for (final (i, at) in schedule.beepTimes.indexed) {
      // The first beep straight away, on Start.
      at == Duration.zero ? light(i) : _timers.add(Timer(at, () => light(i)));
    }
    _timers.add(Timer(schedule.watchFrom, onWatch));
    _timers.add(Timer(schedule.go, () {
      final at = clock();
      sounds.go();
      goAt = at;
      lit = 0;
      phase = StartPhase.go;
      onGo(at);
      notifyListeners();
    }));
    notifyListeners();
  }

  /// Stops a countdown (or forgets a finished one): back to ready.
  void stop() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    if (phase != StartPhase.ready) {
      phase = StartPhase.ready;
      lit = 0;
      goAt = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }
}
