import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/target_camera.dart';
import '../game/quick_draw_judge.dart';
import '../game/quick_draw_targets.dart';
import '../game/quick_draw_watcher.dart';
import '../game/start_signal.dart';
import '../providers.dart';
import 'camera_view.dart';
import 'quick_draw_boards.dart';

/// Quick draw with the phone's live camera (Home → Quick draw): two throwers,
/// one board each, side by side, throwing on the app's start signal.
///
/// 1. The camera fills the screen (system bars hidden); tap the centre of
///    Player 1's board, then Player 2's, and **Lock boards**.
/// 2. **Start**: 5 beeps a second apart, each lighting one of 5 lights, a
///    random pause of 1.0–3.0 s, then a long "go" beep, the lights go out and
///    **GO!** shows ([StartSignal]).
/// 3. From 1 s before go, both boards are analysed on every frame
///    ([QuickDrawWatcher], queued: a slow phone falls behind and reports
///    late, never skips). Each knife is timed from go and judged stuck (with
///    its score) or bounced; one before go is a false start.
/// 4. The result, large enough to read from the throwing line, with a chime;
///    **Next duel** keeps the boards (collect the knives first).
///
/// `docs/thrower/stories/story-checkpoint-live-quick-draw.md`. The recording
/// version is `QuickDrawScreen` (Live test → Quick draw).
class LiveQuickDrawScreen extends ConsumerStatefulWidget {
  const LiveQuickDrawScreen({super.key});

  /// How long after go to wait for throws before giving the result anyway
  /// (a thrower who didn't throw): both knives normally land within ~1 s.
  /// Then no new frames are taken, and the result comes once the frames
  /// already queued are analysed.
  static const resultWindow = Duration(seconds: 4);

  /// The longest a result can take after go, however far behind analysis
  /// is: nobody should have to walk to the phone to end a duel.
  static const resultLimit = Duration(seconds: 15);

  /// How long GO! stays on screen.
  static const goShown = Duration(milliseconds: 700);

  @override
  ConsumerState<LiveQuickDrawScreen> createState() => _LiveQuickDrawScreenState();
}

class _LiveQuickDrawScreenState extends ConsumerState<LiveQuickDrawScreen> with BoardChoosing {
  StartSignal? _signal;
  QuickDrawWatcher? _watcher;
  QuickDrawVerdict? _verdict;

  /// Frames dropped from the queues during the duel (past their memory cap).
  var _dropped = 0;
  Timer? _resultCheck;
  Timer? _goOff;
  var _showGo = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _endDuel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Start: run the start signal; watch from 1 s before go.
  void _start(TargetCamera camera) {
    _endDuel();
    final boards = ref.read(quickDrawTargetsProvider).boards;
    final sounds = ref.read(signalSoundsProvider);
    late final StartSignal signal;
    signal = StartSignal(
      schedule: ref.read(startScheduleProvider)(),
      sounds: sounds,
      clock: () => camera.now,
      onWatch: () {
        if (!mounted) return;
        setState(() => _watcher = QuickDrawWatcher(camera, boards, model: ref.read(targetModelProvider), queue: true)..start());
      },
      onGo: (goAt) {
        if (!mounted) return;
        setState(() => _showGo = true);
        _goOff = Timer(LiveQuickDrawScreen.goShown, () {
          if (mounted) setState(() => _showGo = false);
        });
        _resultCheck = Timer.periodic(const Duration(milliseconds: 250), (_) => _checkResult(camera));
      },
    )..addListener(() {
        if (mounted) setState(() {});
      });
    setState(() {
      _verdict = null;
      _signal = signal;
    });
    signal.start();
  }

  /// The result is in once both throws are; or, [LiveQuickDrawScreen.resultWindow]
  /// after go, no more frames are taken and it comes once those queued are
  /// analysed; or, at the latest, [LiveQuickDrawScreen.resultLimit] after go.
  /// Then watching stops (less heat while the knives are collected).
  void _checkResult(TargetCamera camera) {
    final watcher = _watcher, goAt = _signal?.goAt;
    if (watcher == null || goAt == null || _verdict != null) return;
    final throws = watcher.throws.value;
    final sinceGo = camera.now - goAt;
    if (sinceGo >= LiveQuickDrawScreen.resultWindow) watcher.stopFeeding();
    final caughtUp = watcher.queues.every((q) => q.waiting.value == 0);
    final done = throws.every((t) => t != null) ||
        (sinceGo >= LiveQuickDrawScreen.resultWindow && caughtUp) ||
        sinceGo >= LiveQuickDrawScreen.resultLimit;
    if (!done) return;
    _resultCheck?.cancel();
    final dropped = watcher.queues.fold(0, (n, q) => n + q.dropped);
    watcher.dispose();
    ref.read(signalSoundsProvider).result();
    setState(() {
      _verdict = judgeQuickDraw(throws, goAt);
      _dropped = dropped;
    });
  }

  /// Stops any start signal, watching and result.
  void _endDuel() {
    _resultCheck?.cancel();
    _goOff?.cancel();
    _signal?.dispose();
    _watcher?.dispose();
    _signal = null;
    _watcher = null;
    _verdict = null;
    _dropped = 0;
    _showGo = false;
  }

  /// Next duel: same boards, ready to Start.
  void _nextDuel() => setState(_endDuel);

  /// Choose boards again: forget the boards too.
  void _startAgain() {
    setState(_endDuel);
    ref.read(quickDrawTargetsProvider.notifier).clear();
  }

  String _line(QuickDrawTargets targets) {
    final signal = _signal;
    if (!targets.locked || signal == null) {
      return choosingInstruction(targets, locked: 'Boards locked. Throwers ready? Tap Start: 5 beeps, then go on the long beep.');
    }
    return switch (signal.phase) {
      StartPhase.countdown => 'Wait for the long beep…',
      StartPhase.go || StartPhase.ready => 'Watching…',
    };
  }

  @override
  Widget build(BuildContext context) {
    final targets = ref.watch(quickDrawTargetsProvider);
    final camera = ref.watch(liveQuickDrawCameraProvider).value;
    // Keeps the sounds loaded while Quick draw is open (they are released
    // with nothing watching them: no beeps, which are the throwers' only
    // start signal: Review Agent, 2026-10-15).
    ref.watch(signalSoundsProvider);
    final signal = _signal, watcher = _watcher, verdict = _verdict;
    final duelOn = signal != null;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraView(
            camera: liveQuickDrawCameraProvider,
            overlayBuilder: (context, camera) => BoardsOverlay(
              targets: targets,
              onTap: targets.complete || searching ? null : (tap) => findBoardAt(camera, tap),
              throws: watcher?.throws,
              go: signal?.goAt ?? Duration.zero,
            ),
          ),
          if (signal != null && signal.phase == StartPhase.countdown) _Lights(lit: signal.lit),
          if (_showGo)
            const IgnorePointer(
              child: Center(
                child: Text(
                  'GO!',
                  key: Key('quickDrawGo'),
                  style: TextStyle(color: Colors.greenAccent, fontSize: 96, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 12)]),
                ),
              ),
            ),
          if (verdict != null) QuickDrawResultPanel(verdict: verdict, framesSkipped: _dropped > 0),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    key: const Key('quickDrawBack'),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (kDebugMode && watcher != null && verdict == null) ...[
                        _WatchDebugLine(watcher: watcher),
                        const SizedBox(height: 8),
                      ],
                      if (verdict == null) quickDrawLine(_line(targets)),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (targets.boards.isNotEmpty)
                            OutlinedButton(
                              key: const Key('quickDrawStartAgain'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.black54),
                              onPressed: _startAgain,
                              child: const Text('Choose boards again'),
                            ),
                          if (targets.complete && !targets.locked)
                            FilledButton(
                              key: const Key('quickDrawLock'),
                              onPressed: ref.read(quickDrawTargetsProvider.notifier).lock,
                              child: const Text('Lock boards'),
                            ),
                          if (targets.locked && !duelOn && camera != null)
                            FilledButton(
                              key: const Key('quickDrawStart'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _start(camera),
                              child: const Text('Start'),
                            ),
                          // Stop for the whole duel, until the result.
                          if (signal != null && verdict == null)
                            OutlinedButton(
                              key: const Key('quickDrawStop'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.black54),
                              onPressed: _nextDuel,
                              child: const Text('Stop'),
                            ),
                          if (verdict != null)
                            FilledButton(
                              key: const Key('quickDrawNextDuel'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _nextDuel,
                              child: const Text('Next duel'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The 5 start lights, one lit with each beep (Formula 1 style).
class _Lights extends StatelessWidget {
  const _Lights({required this.lit});

  final int lit;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.55),
        child: Container(
          key: const Key('quickDrawLights'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 5; i++)
                Container(
                  key: Key('quickDrawLight$i${i < lit ? 'On' : 'Off'}'),
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i < lit ? Colors.red : Colors.grey.shade800),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The result, large enough to read from the throwing line (about 4 m):
/// who won, then each player's time after go and score; and, if the phone
/// couldn't keep up and frames were skipped, a note that times may be less
/// exact (otherwise only debug builds would show it).
class QuickDrawResultPanel extends StatelessWidget {
  const QuickDrawResultPanel({super.key, required this.verdict, this.framesSkipped = false});

  final QuickDrawVerdict verdict;
  final bool framesSkipped;

  /// "Player 2 wins", "A draw" or "No winner".
  static String headline(QuickDrawVerdict v) => switch (v.winner) {
        final w? => 'Player ${w + 1} wins',
        null => v.draw ? 'A draw' : 'No winner',
      };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const Key('quickDrawResult'),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(headline(verdict),
                key: const Key('quickDrawHeadline'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.greenAccent, fontSize: 52, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            for (final (i, p) in verdict.players.indexed)
              Text('${i + 1}:  ${judgedText(p)}',
                  key: Key('quickDrawResultPlayer$i'),
                  style: TextStyle(
                    color: i == verdict.winner ? Colors.white : Colors.white70,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  )),
            if (framesSkipped) ...[
              const SizedBox(height: 8),
              const Text('Some frames were skipped: times may be less exact.',
                  key: Key('quickDrawFramesSkipped'), style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Debug builds: each board's watch state and how far behind its analysis
/// is, e.g. "1: watching · 2: motion · 0.03 s behind".
class _WatchDebugLine extends StatelessWidget {
  const _WatchDebugLine({required this.watcher});

  final QuickDrawWatcher watcher;

  @override
  Widget build(BuildContext context) {
    final listenables = [...watcher.states, for (final q in watcher.queues) q.waiting];
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final states = [for (final (i, s) in watcher.states.indexed) '${i + 1}: ${s.value.name}'];
        final behind = watcher.queues.fold(Duration.zero, (m, q) => q.behind > m ? q.behind : m);
        final dropped = watcher.queues.fold(0, (n, q) => n + q.dropped);
        return Container(
          color: Colors.black54,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '${states.join(' · ')} · ${(behind.inMilliseconds / 1000).toStringAsFixed(2)} s behind'
            '${dropped > 0 ? ' · $dropped dropped' : ''}',
            key: const Key('quickDrawWatchDebug'),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        );
      },
    );
  }
}
