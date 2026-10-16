import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/game_history.dart';
import '../history/game_record.dart';
import '../providers.dart';
import '../scoring/match.dart';

/// Home → History (game-history story, Task 3): the finished games kept on
/// this phone, newest first. Tap one for every round of each player; delete
/// one there, or **Clear history** here (after asking). If the history
/// can't be read it says so, and Play still works.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<List<GameRecord>> _games = _load();

  Future<List<GameRecord>> _load() => ref.read(gameHistoryProvider).load();

  void _reload() => setState(() {
        _games = _load();
      });

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
  Widget build(BuildContext context) => FutureBuilder<List<GameRecord>>(
        future: _games,
        builder: (context, snapshot) {
          final games = snapshot.data;
          return Scaffold(
            appBar: AppBar(
              title: const Text('History'),
              actions: [
                if (games != null && games.isNotEmpty)
                  TextButton(key: const Key('historyClear'), onPressed: _clear, child: const Text('Clear history')),
              ],
            ),
            body: SafeArea(top: false, child: _body(context, snapshot)),
          );
        },
      );

  Widget _body(BuildContext context, AsyncSnapshot<List<GameRecord>> snapshot) {
    if (snapshot.hasError) {
      final error = snapshot.error;
      return _Message(
        key: const Key('historyLoadFailed'),
        text: "Couldn't load the history",
        detail: error is GameHistoryException ? error.message : '$error',
        action: OutlinedButton(onPressed: _reload, child: const Text('Try again')),
      );
    }
    final games = snapshot.data;
    if (games == null) return const Center(child: CircularProgressIndicator());
    if (games.isEmpty) {
      return const _Message(
        key: Key('historyEmpty'),
        text: 'No games yet',
        detail: 'Each game of Play is kept here when it finishes.',
      );
    }
    return ListView.separated(
      itemCount: games.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => ListTile(
        key: Key('historyGame-${games[i].id}'),
        title: Text(whenText(games[i].finishedAt)),
        subtitle: Text(summaryText(games[i])),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(games[i]),
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
            if (game.players.length > 1) ...[
              const SizedBox(height: 8),
              Text(resultText(game), key: const Key('historyResult'), style: theme.textTheme.headlineSmall),
            ],
            for (final (p, rounds) in game.players.indexed) ...[
              const SizedBox(height: 24),
              Text(
                game.players.length > 1 ? 'Player ${p + 1}: ${totals[p]}' : 'Total: ${totals[p]}',
                key: Key('historyPlayer-$p'),
                style: theme.textTheme.titleLarge,
              ),
              for (final (r, total) in rounds.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Round ${r + 1}: $total', key: Key('historyRound-$p-$r')),
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

/// "2 players, 1 target · 5 rounds", with "Live test: Target 1" for a game
/// played on a recording.
String howText(GameRecord game) => [
      switch (game.mode) {
        PlayMode.solo => '1 player',
        PlayMode.sharedTarget => '2 players, 1 target',
        PlayMode.twoTargets => '2 players, 2 targets',
      },
      '${game.rounds} rounds',
      if (game.recording case final name?) 'Live test: $name',
    ].join(' · ');

/// "Player 2 wins 61–58", "A draw 40–40", or one player's total.
String resultText(GameRecord game) {
  final totals = game.totals;
  if (totals.length == 1) return 'Total ${totals.single}';
  final score = totals.join('–');
  return game.draw ? 'A draw $score' : 'Player ${game.winner! + 1} wins $score';
}

/// A list line under the date: how it was played, then the result.
String summaryText(GameRecord game) => '${howText(game)} · ${resultText(game)}';
