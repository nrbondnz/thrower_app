import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/game_history.dart';
import '../history/game_record.dart';
import '../history/throw_stats.dart';
import '../providers.dart';
import '../scoring/game_type.dart';
import '../scoring/match.dart';
import 'history_post_panel.dart';
import 'theme/widgets.dart';

/// The History tab (game-history story, Task 3; app-design story,
/// 2026-10-23): the stats over the sessions kept on this phone
/// ([ThrowStats]), then the sessions, newest first. Tap one for every round
/// of each player; delete one there, or **Clear history** here (after
/// asking). If the history can't be read it says so, and Play still works.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  void _reload() => ref.invalidate(keptGamesProvider);

  Future<void> _clear() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('Every kept game is removed from this phone. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            key: const Key('historyClearConfirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await ref.read(gameHistoryProvider).clear();
    } on GameHistoryException catch (e) {
      if (mounted) _say("Couldn't clear the history: ${e.message}");
    }
    _reload();
  }

  Future<void> _open(GameRecord game) async {
    final deleted = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => GameRecordScreen(game: game)));
    if (deleted == true) _reload();
  }

  void _say(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final kept = ref.watch(keptGamesProvider);
    final games = kept.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (games != null && games.isNotEmpty)
            TextButton(key: const Key('historyClear'), onPressed: _clear, child: const Text('Clear history')),
        ],
      ),
      body: SafeArea(top: false, child: _body(context, kept)),
    );
  }

  Widget _body(BuildContext context, AsyncValue<List<GameRecord>> kept) {
    if (kept.hasError && !kept.isLoading) {
      final error = kept.error;
      return _Message(
        key: const Key('historyLoadFailed'),
        text: "Couldn't load the history",
        detail: error is GameHistoryException ? error.message : '$error',
        action: OutlinedButton(onPressed: _reload, child: const Text('Try again')),
      );
    }
    final games = kept.value;
    if (games == null) return const Center(child: CircularProgressIndicator());
    if (games.isEmpty) {
      return const _Message(
        key: Key('historyEmpty'),
        text: 'No games yet',
        detail: 'Each game of Play is kept here when it finishes.',
      );
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        StatsCard(stats: ThrowStats.of(games)),
        const SectionHeading('Sessions'),
        for (final g in games) ...[
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: Key('historyGame-${g.id}'),
              title: Text(whenText(g.finishedAt), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summaryText(g)),
                  const SizedBox(height: 4),
                  PostStatusLabel(game: g),
                ],
              ),
              trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
              onTap: () => _open(g),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// History's stats (docs/thrower/AppDesign/History and Stats.md): sessions,
/// knives and per knife; 5s, hit rate, and the best ranked total (or, before
/// a ranked session, the best round). Says how many sessions the knife
/// stats are from when some were kept before each knife was.
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.stats});

  final ThrowStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = stats;
    return Card(
      key: const Key('historyStats'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            StatRow([
              StatTile(value: '${s.sessions}', label: 'Sessions'),
              StatTile(value: '${s.knives}', label: 'Knives'),
              StatTile(value: perKnifeText(s), label: 'Per knife'),
            ]),
            const SizedBox(height: 16),
            StatRow([
              StatTile(value: '${s.fives}', label: '5s'),
              StatTile(value: hitRateText(s), label: 'Hit rate'),
              if (s.bestRanked case final best?)
                StatTile(value: '$best', label: 'Best ranked')
              else
                StatTile(value: '${s.bestRound ?? '–'}', label: 'Best round'),
            ]),
            if (s.partial) ...[
              const SizedBox(height: 12),
              Text(
                'Knives, per knife, 5s and hit rate: from the ${s.withKnives} of ${s.sessions} sessions '
                'kept with each knife.',
                key: const Key('historyStatsPartial'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One kept game: how it was played, every round of each player, the
/// totals and the result. **Delete** forgets it and goes back to the list.
class GameRecordScreen extends ConsumerWidget {
  const GameRecordScreen({super.key, required this.game});

  final GameRecord game;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(gameHistoryProvider).delete(game.id);
      if (context.mounted) Navigator.of(context).pop(true);
    } on GameHistoryException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Couldn't delete this game: ${e.message}")));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final totals = game.totals;
    final counted = game.countedTotals;
    return Scaffold(
      appBar: AppBar(
        title: Text(whenText(game.finishedAt)),
        actions: [
          IconButton(
            key: const Key('historyDelete'),
            tooltip: 'Delete this game',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(howText(game), style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            HistoryPostPanel(game: game),
            if (game.players.length > 1) ...[
              const SizedBox(height: 8),
              Text(resultText(game), key: const Key('historyResult'), style: theme.textTheme.headlineSmall),
            ],
            for (final (p, rounds) in game.players.indexed) ...[
              const SizedBox(height: 24),
              Text(
                game.players.length > 1 || game.names.firstOrNull != null
                    ? '${game.nameOf(p)}: ${counted[p]}'
                    : 'Total: ${totals[p]}',
                key: Key('historyPlayer-$p'),
                style: theme.textTheme.titleLarge,
              ),
              for (final (r, total) in rounds.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    r < game.countedRounds
                        ? '${historyRoundLabel(game, r)}: $total'
                        : '${historyRoundLabel(game, r)}: $total (not counted)',
                    key: Key('historyRound-$p-$r'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, required this.detail, this.action});

  final String text;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(detail, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "16 Oct, 14:32" (the phone's local time; no year, kept short).
String whenText(DateTime at) =>
    '${at.day} ${_months[at.month - 1]}, ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

/// "2 players, 1 target · 5 rounds" ("2 of 5 rounds" if finished early),
/// with "Live test: Target 1" for a game played on a recording. Precision
/// and Three targets lead with the game ("Precision · 2 players, taking
/// turns · 7 rounds").
String howText(GameRecord game) => [
      if (game.type != GameType.scoring) game.type.label,
      switch (game.mode) {
        PlayMode.solo => '1 player',
        PlayMode.sharedTarget when game.type != GameType.scoring => '2 players, taking turns',
        PlayMode.sharedTarget => '2 players, 1 target',
        PlayMode.twoTargets => '2 players, 2 targets',
      },
      game.finishedEarly ? '${_played(game)} of ${game.rounds} rounds' : '${game.rounds} rounds',
      if (game.recording case final name?) 'Live test: $name',
    ].join(' · ');

/// "Round 2", or for Precision with its distance, "Round 2 (5 m)".
String historyRoundLabel(GameRecord game, int round) => switch (game.type.distanceOf(round)) {
      final d? => 'Round ${round + 1} ($d m)',
      null => 'Round ${round + 1}',
    };

/// The most rounds anyone played (a finished-early game).
int _played(GameRecord game) => game.players.map((p) => p.length).reduce((a, b) => a > b ? a : b);

/// "Mark wins 61–58" ("Player 2 wins…" without names), "A draw 40–40", or
/// one player's total ("Total 45", "Mark 45"). Two players are judged on
/// equal rounds ([GameRecord.countedTotals]).
String resultText(GameRecord game) {
  if (game.players.length == 1) {
    final name = game.names.firstOrNull;
    return name == null ? 'Total ${game.totals.single}' : '$name ${game.totals.single}';
  }
  final score = game.countedTotals.join('–');
  return game.draw ? 'A draw $score' : '${game.nameOf(game.winner!)} wins $score';
}

/// A list line under the date: how it was played, then the result.
String summaryText(GameRecord game) => '${howText(game)} · ${resultText(game)}';
