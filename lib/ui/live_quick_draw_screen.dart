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
import '../scoring/match.dart';
import '../scoring/quick_draw_match.dart';
import 'camera_view.dart';
import 'quick_draw_boards.dart';

/// Quick draw with the phone's live camera (Home → Quick draw): two throwers,
/// one board each, side by side, throwing on the app's start signal.
///
/// 1. The camera fills the screen (system bars hidden); tap the centre of
///    Player 1's board, then Player 2's, and **Lock boards**.
/// 2. **Start**: 5 beeps a second apart, each lighting one of 5 lights, a
///    random pause of 1.0–3.0 s, then a long, higher "go" beep and the lights
///    go out ([StartSignal]). Nothing else shows at go: the beep is the
///    signal (Nigel, 2026-10-16).
/// 3. From 1 s before go, both boards are analysed on every frame
///    ([QuickDrawWatcher], queued: a slow phone falls behind and reports
///    late, never skips). Each knife is timed from go and judged stuck (with
///    its score) or bounced; one before go is a false start.
/// 4. The round's result, large enough to read from the throwing line, with
///    a chime, and the match so far.
/// 5. A match is three rounds ([QuickDrawMatch], Nigel's brother,
///    2026-10-19), with extra rounds if level: **Next round** (or **Extra
///    round**) keeps the boards (collect the knives first); **Finish match**
///    ends it early (asking first); at the end, **New match**.
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

  @override
  ConsumerState<LiveQuickDrawScreen> createState() => _LiveQuickDrawScreenState();
}

class _LiveQuickDrawScreenState extends ConsumerState<LiveQuickDrawScreen> with BoardChoosing {
  StartSignal? _signal;
  QuickDrawWatcher? _watcher;
  QuickDrawVerdict? _verdict;
  var _match = const QuickDrawMatch();

  /// Frames dropped from the queues during the duel (past their memory cap).
  var _dropped = 0;
  Timer? _resultCheck;

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
    final targets = ref.read(quickDrawTargetsProvider);
    final sounds = ref.read(signalSoundsProvider);
    late final StartSignal signal;
    signal =
        StartSignal(
          schedule: ref.read(startScheduleProvider)(),
          sounds: sounds,
          clock: () => camera.now,
          onWatch: () {
            if (!mounted) return;
            setState(
              () => _watcher = QuickDrawWatcher(
                camera,
                targets.boards,
                model: ref.read(targetModelProvider),
                queue: true,
                areas: targets.areas,
              )..start(),
            );
          },
          onGo: (goAt) {
            if (!mounted) return;
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
    final done =
        throws.every((t) => t != null) ||
        (sinceGo >= LiveQuickDrawScreen.resultWindow && caughtUp) ||
        sinceGo >= LiveQuickDrawScreen.resultLimit;
    if (!done) return;
    _resultCheck?.cancel();
    final dropped = watcher.queues.fold(0, (n, q) => n + q.dropped);
    watcher.dispose();
    ref.read(signalSoundsProvider).result();
    final verdict = judgeQuickDraw(throws, goAt);
    setState(() {
      _verdict = verdict;
      _match = _match.add(verdict.winner);
      _dropped = dropped;
    });
  }

  /// Stops any start signal, watching and result.
  void _endDuel() {
    _resultCheck?.cancel();
    _signal?.dispose();
    _watcher?.dispose();
    _signal = null;
    _watcher = null;
    _verdict = null;
    _dropped = 0;
  }

  /// Next round (or Stop): same boards, ready to Start. A stopped round
  /// doesn't count.
  void _nextRound() => setState(_endDuel);

  /// New match: same boards, no rounds won.
  void _newMatch() => setState(() {
    _endDuel();
    _match = const QuickDrawMatch();
  });

  /// Finish match, after asking: decided on the rounds won so far.
  Future<void> _finishMatch() async {
    if (await confirmFinishMatch(context) && mounted) setState(() => _match = _match.finish());
  }

  /// Choose boards again: forget the boards too.
  void _startAgain() {
    setState(_endDuel);
    ref.read(quickDrawTargetsProvider.notifier).clear();
  }

  String _line(QuickDrawTargets targets) {
    final signal = _signal;
    if (!targets.locked || signal == null) {
      const ready = 'Throwers ready? Tap Start: 5 beeps, then go on the long beep.';
      final m = _match;
      if (targets.locked && m.results.isNotEmpty) {
        return '${roundLabel(m.roundNumber, m.rounds)} (${matchText(m, playerNames)}). $ready';
      }
      return choosingInstruction(targets, locked: 'Boards locked. $ready', drawn: ref.watch(boardsDrawnProvider));
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
    final signal = _signal, watcher = _watcher, verdict = _verdict, match = _match;
    final duelOn = signal != null;
    final drawn = ref.watch(boardsDrawnProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraView(
            camera: liveQuickDrawCameraProvider,
            overlayBuilder: (context, camera) => BoardsOverlay(
              targets: targets,
              onTap: targets.complete || searching || drawn ? null : (tap) => findBoardAt(camera, tap),
              onDraw: targets.complete || searching || !drawn ? null : (loop) => addDrawnBoard(camera, loop),
              onAdjust: targets.complete && !targets.locked
                  ? ref.read(quickDrawTargetsProvider.notifier).replace
                  : null,
              throws: watcher?.throws,
              go: signal?.goAt ?? Duration.zero,
            ),
          ),
          if (signal != null && signal.phase == StartPhase.countdown) _Lights(lit: signal.lit),
          if (verdict != null || match.isOver)
            QuickDrawResultPanel(verdict: verdict, match: match, names: playerNames, framesSkipped: _dropped > 0),
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
                      if (verdict == null && !match.isOver) quickDrawLine(_line(targets)),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (!duelOn) const NamesButton(),
                          if (targets.boards.isEmpty && !searching) boardsModeButton(),
                          if (targets.boards.isNotEmpty)
                            OutlinedButton(
                              key: const Key('quickDrawStartAgain'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.black54,
                              ),
                              onPressed: _startAgain,
                              child: const Text('Choose boards again'),
                            ),
                          if (targets.complete && !targets.locked)
                            FilledButton(
                              key: const Key('quickDrawLock'),
                              onPressed: ref.read(quickDrawTargetsProvider.notifier).lock,
                              child: const Text('Lock boards'),
                            ),
                          if (targets.locked && !duelOn)
                            OutlinedButton(
                              key: const Key('quickDrawAdjust'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.black54,
                              ),
                              onPressed: ref.read(quickDrawTargetsProvider.notifier).unlock,
                              child: const Text('Adjust boards'),
                            ),
                          if (targets.locked && !duelOn && !match.isOver && camera != null)
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
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.black54,
                              ),
                              onPressed: _nextRound,
                              child: const Text('Stop'),
                            ),
                          if (verdict != null && !match.isOver)
                            FilledButton(
                              key: const Key('quickDrawNextRound'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _nextRound,
                              child: Text(match.isExtraRound ? 'Extra round' : 'Next round'),
                            ),
                          // After any round, between rounds or on its result.
                          if (match.results.isNotEmpty && !match.isOver && (verdict != null || !duelOn))
                            OutlinedButton(
                              key: const Key('quickDrawFinishMatch'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.black54,
                              ),
                              onPressed: _finishMatch,
                              child: const Text('Finish match'),
                            ),
                          if (match.isOver)
                            FilledButton(
                              key: const Key('quickDrawNewMatch'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _newMatch,
                              child: const Text('New match'),
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

/// "Round 2 of 3", or "Extra round" past the match's [rounds].
String roundLabel(int round, int rounds) => round <= rounds ? 'Round $round of $rounds' : 'Extra round';

/// The match so far, or its result: "Player 2 leads 1–0", "Level 1–1";
/// "Player 2 wins the match 2–1", "Match drawn 1–1" (the leader's wins
/// first). Players by [names] ("Player N" without one).
String matchText(QuickDrawMatch m, [List<String> names = const []]) {
  String name(int p) => names.elementAtOrNull(p) ?? playerNumber(p);
  String ahead(int p) => '${m.wins[p]}–${m.wins[1 - p]}';
  if (m.isOver) {
    return m.draw ? 'Match drawn ${m.scoreText}' : '${name(m.winner!)} wins the match ${ahead(m.winner!)}';
  }
  final leader = m.leader;
  return leader == null ? 'Level ${m.scoreText}' : '${name(leader)} leads ${ahead(leader)}';
}

/// Asks before ending a Quick draw match early.
Future<bool> confirmFinishMatch(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish the match now?'),
        content: const Text('It ends on the rounds won so far; if they are level, it is a draw.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            key: const Key('quickDrawFinishConfirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finish'),
          ),
        ],
      ),
    ) ??
    false;

/// The result, large enough to read from the throwing line (about 4 m): the
/// round and who won it, then each player's time after go and score, then
/// the match so far (or its result, in green); and, if the phone couldn't
/// keep up and frames were skipped, a note that times may be less exact
/// (otherwise only debug builds would show it). With no [verdict] (a match
/// finished between rounds), only the match result.
class QuickDrawResultPanel extends StatelessWidget {
  const QuickDrawResultPanel({
    super.key,
    this.verdict,
    required this.match,
    this.names = const [],
    this.framesSkipped = false,
  });

  final QuickDrawVerdict? verdict;
  final QuickDrawMatch match;

  /// The players' names, Player 1 first ("Player N" without one).
  final List<String> names;
  final bool framesSkipped;

  /// "Player 2 wins" (by [names]: "Sam wins"), "… wins on score", "A draw"
  /// or "No winner".
  static String headline(QuickDrawVerdict v, [List<String> names = const []]) => switch (v.winner) {
    final w? => '${names.elementAtOrNull(w) ?? playerNumber(w)} wins${v.byScore ? ' on score' : ''}',
    null => v.draw ? 'A draw' : 'No winner',
  };

  @override
  Widget build(BuildContext context) {
    // Wraps to the screen's width; if it's still too tall (a phone held
    // sideways), scales down to fit rather than overflowing.
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth - 32),
              child: _panel(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel() {
    return Container(
      key: const Key('quickDrawResult'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (verdict case final verdict?) ...[
            Text(
              roundLabel(match.results.length, match.rounds),
              key: const Key('quickDrawRound'),
              style: const TextStyle(color: Colors.white70, fontSize: 24),
            ),
            Text(
              headline(verdict, names),
              key: const Key('quickDrawHeadline'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.greenAccent, fontSize: 52, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            for (final (i, p) in verdict.players.indexed)
              Text(
                '${i + 1}:  ${judgedText(p)}',
                key: Key('quickDrawResultPlayer$i'),
                style: TextStyle(
                  color: i == verdict.winner ? Colors.white : Colors.white70,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 12),
          ],
          Text(
            matchText(match, names),
            key: const Key('quickDrawMatch'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: match.isOver ? Colors.greenAccent : Colors.white,
              fontSize: match.isOver ? 44 : 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (framesSkipped) ...[
            const SizedBox(height: 8),
            const Text(
              'Some frames were skipped: times may be less exact.',
              key: Key('quickDrawFramesSkipped'),
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ],
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
