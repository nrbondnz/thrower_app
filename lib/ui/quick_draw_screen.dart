import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/recorded_camera.dart';
import '../camera/recording_analysis_feed.dart';
import '../game/quick_draw_judge.dart';
import '../game/quick_draw_watcher.dart';
import '../providers.dart';
import 'camera_view.dart';
import 'quick_draw_boards.dart';
import 'recorded_preview.dart';

/// Quick draw on a recording (Live test → Quick draw): two throwers, one board
/// each, both in one view. The live camera's Quick draw is
/// `LiveQuickDrawScreen`; both choose the boards the same way
/// (`quick_draw_boards.dart`).
/// It plays the clip full screen with its sound (the system bars hidden).
/// Before playing, the user taps the centre of Player 1's board, then
/// Player 2's (there may be more boards in the picture), and locks them.
/// Played locked, "GO" flashes when the footage's countdown says it; every
/// frame is analysed in order (possibly finishing a little after the
/// picture), each board shows its knife's time after go and its score, and
/// the result line says who won ([judgeQuickDraw]).
/// (`docs/thrower/stories/archive/story-checkpoint-quick-draw.md`).
class QuickDrawScreen extends ConsumerStatefulWidget {
  const QuickDrawScreen({super.key});

  @override
  ConsumerState<QuickDrawScreen> createState() => _QuickDrawScreenState();
}

class _QuickDrawScreenState extends ConsumerState<QuickDrawScreen> with BoardChoosing {
  /// Every frame of the clip, in order, for the watcher.
  RecordingAnalysisFeed? _feed;

  /// Times and scores the throws while a locked game plays.
  QuickDrawWatcher? _watcher;

  /// Play: with the boards locked, a fresh watcher times and scores each
  /// player's throw from every frame; otherwise the clip just plays.
  void _play(RecordedCamera camera) {
    _stopWatching();
    final targets = ref.read(quickDrawTargetsProvider);
    if (targets.locked) {
      final go = camera.recording.go;
      final feed = RecordingAnalysisFeed(camera, from: go == null ? Duration.zero : go - quickDrawLeadIn);
      setState(() {
        _feed = feed;
        _watcher = QuickDrawWatcher(feed, targets.boards, model: ref.read(targetModelProvider))..start();
      });
    }
    camera.restart();
  }

  void _stopWatching() {
    _watcher?.dispose();
    _feed?.dispose();
    _watcher = null;
    _feed = null;
  }

  /// While a locked game is analysed: the result once both throws are in
  /// (or the whole clip has been analysed), otherwise how far analysis has
  /// got.
  String _progress(RecordedCamera camera, RecordingAnalysisFeed feed, List<QuickDrawThrow?> throws) {
    final done = feed.analysed.value >= camera.pack.frameCount - 1;
    if (throws.every((t) => t != null) || done) return verdictText(judgeQuickDraw(throws, camera.recording.go!));
    final behind = camera.position.value - feed.timeOf(math.max(feed.first, feed.analysed.value));
    if (camera.position.value < feed.timeOf(feed.first)) return 'Watching…';
    if (behind > const Duration(milliseconds: 200)) {
      return 'Analysing… ${(behind.inMilliseconds / 1000).toStringAsFixed(1)} s behind the picture.';
    }
    return 'Watching…';
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _stopWatching();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = ref.watch(quickDrawCameraProvider);
    final targets = ref.watch(quickDrawTargetsProvider);
    final notifier = ref.read(quickDrawTargetsProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: switch (camera) {
              AsyncData(:final value) => RecordedPreview(
                  camera: value,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      BoardsOverlay(
                        targets: targets,
                        onTap: targets.complete || searching ? null : (tap) => findBoardAt(value, tap),
                        tapsOff: value.playing,
                        throws: _watcher?.throws,
                        go: value.recording.go ?? Duration.zero,
                      ),
                      if (value.recording.go case final go?) _GoFlash(camera: value, go: go),
                      if (kDebugMode)
                        Align(
                          alignment: Alignment.topRight,
                          child: Padding(padding: const EdgeInsets.all(8), child: FrameRateLabel(source: value)),
                        ),
                    ],
                  ),
                ),
              AsyncError(:final error) => Text("The Quick draw clip couldn't load: $error", style: const TextStyle(color: Colors.white)),
              _ => const CircularProgressIndicator(),
            },
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton.filledTonal(
                    key: const Key('quickDrawBack'),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                if (camera case AsyncData(:final value))
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        switch ((_watcher, _feed)) {
                          (final watcher?, final feed?) => ListenableBuilder(
                              listenable: Listenable.merge([watcher.throws, feed.analysed, value.position]),
                              builder: (context, _) => quickDrawLine(_progress(value, feed, watcher.throws.value)),
                            ),
                          _ => quickDrawLine(choosingInstruction(targets, locked: 'Boards locked. Press Play.')),
                        },
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
                                onPressed: () {
                                  setState(_stopWatching);
                                  notifier.clear();
                                  // Choose again on the still board, not where playback stopped.
                                  value.rewind();
                                },
                                child: const Text('Choose boards again'),
                              ),
                            if (targets.complete && !targets.locked)
                              FilledButton(
                                key: const Key('quickDrawLock'),
                                onPressed: notifier.lock,
                                child: const Text('Lock boards'),
                              ),
                            _PlayButton(camera: value, onPlay: () => _play(value)),
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

/// "GO!" over the picture for a moment when the footage's countdown says go.
class _GoFlash extends StatelessWidget {
  const _GoFlash({required this.camera, required this.go});

  final RecordedCamera camera;
  final Duration go;

  /// How long it shows.
  static const shown = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: camera.position,
      builder: (context, position, _) {
        final on = camera.playing.value && position >= go && position < go + shown;
        return IgnorePointer(
          child: Center(
            child: on
                ? Text(
                    'GO!',
                    key: const Key('quickDrawGo'),
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      shadows: const [Shadow(blurRadius: 12)],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// Plays the clip from the start; hidden while it plays.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.camera, required this.onPlay});

  final RecordedCamera camera;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: camera.playing,
      builder: (context, playing, _) => playing
          ? const SizedBox.shrink()
          : FilledButton.icon(
              key: const Key('quickDrawPlay'),
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow),
              label: Text(camera.position.value == Duration.zero ? 'Play' : 'Play again'),
            ),
    );
  }
}
