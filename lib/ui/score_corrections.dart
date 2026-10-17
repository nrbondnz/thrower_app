import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../scoring/game_session.dart';
import '../scoring/match.dart';

/// Score corrections (Nigel, 2026-10-17): every throw's score on Play can be
/// tapped for a 0–5 popup (a dispute), and an empty slot adds a throw the
/// camera didn't see (0: a knife that missed the board). The controls sit
/// below the picture, never on it, and are big enough to tap lightly.

/// What a Play screen does around a score popup: watching pauses while it's
/// open (a hand at the phone isn't a throw), and a throw added by hand gets
/// its mark beside the board.
abstract interface class CorrectionHost {
  void pauseWatching();
  void resumeWatching();

  /// A throw was added by hand at [board] as [slot]; [newRound]: it started
  /// a new round (the board's marks start afresh).
  void addedByHand(int board, ThrowSlot slot, {required bool newRound});
}

/// The scores a throw can have: 0 and each ring's score, lowest first.
List<int> scoreChoices(Iterable<int> ringScores) => {0, ...ringScores}.toList()..sort();

/// The popup: [scores] as large buttons and Cancel. Null if cancelled.
Future<int?> showScorePicker(BuildContext context, {required String title, required List<int> scores, int? current}) =>
    showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final s in scores)
              SizedBox(
                width: 64,
                height: 64,
                child: OutlinedButton(
                  key: Key('pickScore$s'),
                  onPressed: () => Navigator.of(context).pop(s),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    // The score it has now stands out.
                    side: s == current ? const BorderSide(width: 3) : null,
                  ),
                  child: Text('$s'),
                ),
              ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))],
      ),
    );

/// The round a player's slots show: the one in progress, or none once the
/// knives are collected (the next round, not yet thrown).
int? shownRound(GameSession game) => game.awaitingNextRound || game.rounds.isEmpty ? null : game.rounds.length - 1;

/// One player's corrections row: the shown round's throws as big slots
/// (an empty one adds a throw, when it's this player's to throw), then
/// **Rounds**, which lists the player's other rounds to open one. One row a
/// player, so Play's panel stays short. On two players, [label] names the
/// player.
class ScoreCorrections extends ConsumerWidget {
  const ScoreCorrections({super.key, required this.host, required this.player, required this.board, this.label});

  final CorrectionHost host;
  final int player;

  /// The board this player throws at (one target: 0).
  final int board;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(gameProvider);
    final game = match.players[player];
    final shown = shownRound(game);
    final throws = shown == null ? const <ThrowRecord>[] : game.rounds[shown].throws;
    final canAdd = !match.isOver && match.takesThrowAt(board) && match.nextThrowerAt(board) == player;
    final earlier = [
      for (var r = 0; r < game.rounds.length; r++)
        if (r != shown) r,
    ];
    // Shrinks rather than overflows on a narrow phone.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(label!, style: const TextStyle(color: Colors.white70)),
            ),
          for (var i = 0; i < game.throwsPerRound; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _Slot(
                key: Key('slot-$player-$i'),
                record: i < throws.length ? throws[i] : null,
                onTap: i < throws.length
                    ? () => _correct(context, ref, shown!, i)
                    : (i == throws.length && canAdd ? () => _add(context, ref) : null),
              ),
            ),
          if (earlier.isNotEmpty)
            TextButton(
              key: Key('rounds-$player'),
              onPressed: () => _openRounds(context, ref, earlier),
              child: const Text('Rounds'),
            ),
        ],
      ),
    );
  }

  List<int> _scores(WidgetRef ref) => scoreChoices([for (final r in ref.read(targetModelProvider).rings) r.score]);

  /// Opens the popup with watching paused.
  Future<int?> _pick(BuildContext context, WidgetRef ref, String title, {int? current}) async {
    host.pauseWatching();
    try {
      return await showScorePicker(context, title: title, scores: _scores(ref), current: current);
    } finally {
      host.resumeWatching();
    }
  }

  Future<void> _correct(BuildContext context, WidgetRef ref, int round, int index) async {
    final current = ref.read(gameProvider).players[player].rounds[round].throws[index].score;
    final score = await _pick(context, ref, 'Round ${round + 1}, throw ${index + 1}', current: current);
    if (score != null && context.mounted) ref.read(gameProvider.notifier).setScore(player, round, index, score);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final score = await _pick(context, ref, 'A throw the camera missed (0: missed the board)');
    if (score == null || !context.mounted) return;
    final before = ref.read(gameProvider);
    final newRound = before.nextThrowStartsRound(board: board);
    ref.read(gameProvider.notifier).addThrow(score, board: board);
    final after = ref.read(gameProvider);
    if (!identical(after, before)) host.addedByHand(board, after.lastThrowAt(board)!, newRound: newRound);
  }

  /// The player's [rounds] to choose from, then the chosen one's throws;
  /// watching stays paused until both are closed.
  Future<void> _openRounds(BuildContext context, WidgetRef ref, List<int> rounds) async {
    final scores = _scores(ref);
    host.pauseWatching();
    try {
      final round = await showDialog<int>(
        context: context,
        builder: (context) => _RoundList(player: player, rounds: rounds),
      );
      if (round == null || !context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _RoundEditor(player: player, round: round, scores: scores),
      );
    } finally {
      host.resumeWatching();
    }
  }
}

/// The player's [rounds], each with its total: tap one to open it.
class _RoundList extends ConsumerWidget {
  const _RoundList({required this.player, required this.rounds});

  final int player;
  final List<int> rounds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider).players[player];
    return SimpleDialog(
      title: const Text('Which round?'),
      children: [
        for (final r in rounds)
          SimpleDialogOption(
            key: Key('round-$player-$r'),
            onPressed: () => Navigator.of(context).pop(r),
            child: Text('Round ${r + 1}: ${game.rounds[r].total}', style: const TextStyle(fontSize: 18)),
          ),
      ],
    );
  }
}

/// An earlier round's throws: tap one to change it, or an empty slot (a
/// round collected early) to add one. Watching is already paused.
class _RoundEditor extends ConsumerWidget {
  const _RoundEditor({required this.player, required this.round, required this.scores});

  final int player;
  final int round;
  final List<int> scores;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider).players[player];
    final throws = game.rounds[round].throws;
    final notifier = ref.read(gameProvider.notifier);
    return AlertDialog(
      title: Text('Round ${round + 1}: ${game.rounds[round].total}'),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < game.throwsPerRound; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _Slot(
                key: Key('roundSlot-$i'),
                record: i < throws.length ? throws[i] : null,
                onTap: i < throws.length
                    ? () async {
                        final s = await showScorePicker(
                          context,
                          title: 'Round ${round + 1}, throw ${i + 1}',
                          scores: scores,
                          current: throws[i].score,
                        );
                        if (s != null && context.mounted) notifier.setScore(player, round, i, s);
                      }
                    : (i == throws.length
                          ? () async {
                              final s = await showScorePicker(
                                context,
                                title: 'A throw the camera missed (0: missed the board)',
                                scores: scores,
                              );
                              if (s != null && context.mounted) notifier.addToRound(player, round, s);
                            }
                          : null),
              ),
            ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))],
    );
  }
}

/// One throw's slot: its score (light blue with a pencil if set by hand,
/// "?" if the camera couldn't see where it went in), or "–" if not thrown.
class _Slot extends StatelessWidget {
  const _Slot({super.key, required this.record, required this.onTap});

  final ThrowRecord? record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = record;
    final corrected = t?.corrected ?? false;
    final text = t == null ? '–' : (t.unscored ? '?' : '${t.score}');
    return SizedBox(
      width: 56,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: corrected ? Colors.lightBlueAccent : Colors.white,
          side: BorderSide(color: corrected ? Colors.lightBlueAccent : Colors.white38),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        child: Text(corrected ? '$text✎' : text),
      ),
    );
  }
}
