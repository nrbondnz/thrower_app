import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/game/start_signal.dart';
import 'package:thrower_app/sound/signal_sounds.dart';

/// Records which sounds were asked for.
class FakeSignalSounds implements SignalSounds {
  final played = <String>[];

  @override
  Future<void> beep() async => played.add('beep');

  @override
  Future<void> go() async => played.add('go');

  @override
  Future<void> result() async => played.add('result');

  @override
  Future<void> dispose() async {}
}

void main() {
  group('the schedule', () {
    test('5 beeps a second apart, then the pause, then go', () {
      final s = StartSchedule(const Duration(milliseconds: 1600));
      expect([for (final t in s.beepTimes) t.inMilliseconds], [0, 1000, 2000, 3000, 4000]);
      expect(s.go, const Duration(milliseconds: 5600));
    });

    test('watching starts 1 s before go', () {
      expect(StartSchedule(const Duration(seconds: 2)).watchFrom, const Duration(seconds: 5));
    });

    test('the pause is one of 1.0, 1.2 … 3.0 s (Nigel, 2026-10-15)', () {
      expect([for (final p in startPauses) p.inMilliseconds], [1000, 1200, 1400, 1600, 1800, 2000, 2200, 2400, 2600, 2800, 3000]);
    });

    test('a random schedule picks among them, and over many starts uses them all', () {
      final random = math.Random(7);
      final seen = {for (var i = 0; i < 500; i++) StartSchedule.random(random).pause};
      expect(seen, startPauses.toSet());
    });
  });

  group('running it', () {
    late FakeSignalSounds sounds;
    late Duration clock;
    late int watched;
    late Duration? wentAt;
    late StartSignal signal;

    void make(Duration pause) {
      sounds = FakeSignalSounds();
      clock = const Duration(seconds: 100);
      watched = 0;
      wentAt = null;
      signal = StartSignal(
        schedule: StartSchedule(pause),
        sounds: sounds,
        clock: () => clock,
        onWatch: () => watched++,
        onGo: (at) => wentAt = at,
      );
    }

    testWidgets('a light and a beep each second, then the lights go out with the go beep', (tester) async {
      make(const Duration(milliseconds: 1400));
      signal.start();
      await tester.pump();
      expect((signal.phase, signal.lit), (StartPhase.countdown, 1));
      expect(sounds.played, ['beep']);
      for (var lit = 2; lit <= 5; lit++) {
        await tester.pump(const Duration(seconds: 1));
        expect(signal.lit, lit);
      }
      expect(sounds.played, ['beep', 'beep', 'beep', 'beep', 'beep']);
      await tester.pump(const Duration(milliseconds: 1399));
      expect(signal.phase, StartPhase.countdown);
      clock = const Duration(seconds: 105, milliseconds: 400);
      await tester.pump(const Duration(milliseconds: 1));
      expect((signal.phase, signal.lit, sounds.played.last), (StartPhase.go, 0, 'go'));
      expect((signal.goAt, wentAt), (clock, clock));
      signal.dispose();
    });

    testWidgets('watching starts 1 s before go, once', (tester) async {
      make(const Duration(seconds: 2));
      signal.start();
      await tester.pump(const Duration(milliseconds: 4999));
      expect(watched, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(watched, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(watched, 1);
      signal.dispose();
    });

    testWidgets('stop cancels the countdown: no more beeps, no go', (tester) async {
      make(const Duration(seconds: 1));
      signal.start();
      await tester.pump(const Duration(seconds: 2));
      signal.stop();
      await tester.pump(const Duration(seconds: 10));
      expect((signal.phase, signal.lit, sounds.played.length, wentAt, watched), (StartPhase.ready, 0, 3, null, 0));
      signal.dispose();
    });
  });
}
