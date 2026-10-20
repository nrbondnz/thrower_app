import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../scoring/game_type.dart';
import '../scoring/match.dart';
import 'play_screen.dart';
import 'score_corrections.dart';

/// Play for the games scored by hand, Precision and Three targets
/// (more-game-types story, Nigel 2026-10-20: "We can worry about the camera
/// later"). No camera: each knife's score is tapped on a pad (5 to 1, or
/// Miss). In large type, to read from the throwing line: whose turn it is
/// and where they throw from (Precision: "From 5 m") or at (Three targets:
/// "At target 2"). Below, each player's round as slots (tap one to change
/// it: [ScoreCorrections]), their totals, and at the end the result. The
/// game is the same [gameProvider] game as Play's, so it is kept in History
/// (and backed up) when it ends.
class ScorePadScreen extends ConsumerStatefulWidget {
  const ScorePadScreen({super.key});

  @override
  ConsumerState<ScorePadScreen> createState() => _ScorePadScreenState();
}

class _ScorePadScreenState extends ConsumerState<ScorePadScreen> implements CorrectionHost {
  // Nothing is watching the board, so a hand at the phone pauses nothing,
  // and a throw added by hand has no mark to draw.
  @override
  void pauseWatching() {}

  @override
  void resumeWatching() {}

  @override
  void addedByHand(int board, ThrowSlot slot, {required bool newRound}) {}

  Future<void> _finishGame() async {
    if (await confirmFinishGame(context) && mounted) ref.read(gameProvider.notifier).finishGame();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(historySaveErrorProvider, (_, message) {
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(key: Key('historySaveFailed'), content: Text("Couldn't save this game to History.")),
        );
      }
    });
    final match = ref.watch(gameProvider);
    final game = ref.read(gameProvider.notifier);
    const big = TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold);
    const detail = TextStyle(color: Colors.yellowAccent, fontSize: 20);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(match.type.label),
        actions: [
          TextButton(
            key: const Key('finishGame'),
            onPressed: match.isEmpty || match.isOver ? null : _finishGame,
            child: const Text('Finish game'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(padHeadline(match), key: const Key('padHeadline'), textAlign: TextAlign.center, style: big),
            if (padWhere(match) case final where?)
              Text(where, key: const Key('padWhere'), textAlign: TextAlign.center, style: detail),
            const SizedBox(height: 16),
            if (!match.isOver) ...[
              ScorePad(onScore: game.addThrow),
              const SizedBox(height: 8),
              const Text(
                'Tap each knife\'s score when no one is throwing, or have someone who isn\'t throwing keep score.',
                key: Key('padSafety'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
            ],
            for (var p = 0; p < match.players.length; p++) ...[
              Text(playerTitle(match, p), key: Key('playerTitle$p'), style: const TextStyle(color: Colors.white, fontSize: 20)),
              Text(padPlayerDetail(match, p), key: Key('playerDetail$p'), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: ScoreCorrections(
                  host: this,
                  player: p,
                  board: 0,
                  label: match.players.length > 1 ? rowLabel(match, p) : null,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (match.isOver) ...[
              if (match.finishedEarly)
                Text(
                  'Finished early: judged on ${match.countedRounds} of ${match.maxRounds} rounds.',
                  style: const TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 16),
              FilledButton(key: const Key('padNewGame'), onPressed: game.newGame, child: const Text('New game')),
            ],
          ],
        ),
      ),
    );
  }
}

/// The score buttons, largest first: 5, 4, 3, 2, 1, then Miss (0).
class ScorePad extends ConsumerWidget {
  const ScorePad({super.key, required this.onScore});

  final void Function(int score) onScore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = scoreChoices([for (final r in ref.watch(targetModelProvider).rings) r.score]).reversed;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final s in scores)
          SizedBox(
            width: s == 0 ? 120 : 72,
            height: 72,
            child: FilledButton(
              key: Key('pad$s'),
              onPressed: () => onScore(s),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                backgroundColor: s == 0 ? Colors.blueGrey : null,
              ),
              child: Text(s == 0 ? 'Miss' : '$s'),
            ),
          ),
      ],
    );
  }
}

/// The large line: the result once it's over ("Mark wins", "A draw",
/// "Game over! 84"); while it's on, who throws next ("Mark's turn", or
/// "Your turn" alone), or, with every knife of a turn in, "Collect your
/// knives".
String padHeadline(Match match) {
  if (match.isOver) {
    if (match.players.length > 1) return turnText(match)!;
    return 'Game over! ${match.countedTotals.single}';
  }
  if (_collecting(match)) return 'Collect your knives';
  return match.players.length > 1 ? "${match.nameOf(match.nextThrowerAt(0))}'s turn" : 'Your turn';
}

/// Under the headline: where the next knife is thrown from or at, and which
/// round it is in ("Round 2 of 7: from 5 m", "Round 1 of 3: at target 2");
/// once a turn has all its knives, when to collect and who's next.
String? padWhere(Match match) {
  if (match.isOver) return null;
  if (_collecting(match)) {
    final next = match.players.length > 1 ? " Then ${match.nameOf(match.nextThrowerAt(0))}'s turn." : '';
    return 'When no one is throwing.$next';
  }
  final player = match.nextThrowerAt(0);
  final round = 'Round ${_nextRoundNumber(match, player)} of ${match.maxRounds}';
  return switch (match.type) {
    GameType.precision => '$round: from ${match.nextDistance} m',
    GameType.threeTargets => '$round: at target ${match.nextTarget}',
    GameType.scoring => round,
  };
}

/// A turn (or one player's round) has all its knives: they're collected
/// before the next knife.
bool _collecting(Match match) => match.mode == PlayMode.sharedTarget
    ? match.turnComplete
    : match.players.single.roundComplete && !match.players.single.awaitingNextRound;

/// The round (1-based) [player]'s next knife is in.
int _nextRoundNumber(Match match, int player) {
  final g = match.players[player];
  return g.rounds.isEmpty ? 1 : (g.roundComplete ? g.rounds.length + 1 : g.rounds.length);
}

/// A player's rounds so far, each total with, for Precision, its distance
/// ("3 m: 12, 5 m: 9"); once the match is over, a round beyond the
/// [Match.countedRounds] is marked "not counted".
String padPlayerDetail(Match match, int player) {
  final rounds = match.players[player].rounds;
  if (rounds.isEmpty) return 'No knives yet';
  final parts = [
    for (final (i, r) in rounds.indexed)
      [
        if (match.type.distanceOf(i) case final d?) '$d m: ${r.total}' else '${r.total}',
        if (match.isOver && i >= match.countedRounds) ' (not counted)',
      ].join(),
  ];
  return 'Rounds: ${parts.join(', ')}';
}
