import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../leaderboard/leaderboard_service.dart';
import '../providers.dart';
import 'post_score_panel.dart';

/// A leaderboard's tables (backlog #22): **This week** and **Last week**, each
/// the top 25 by Game Center nickname, with the player's own row highlighted
/// (or under the table if they're further down). **Open in Game Center**
/// shows Apple's own screen. iPhone only, as posting (Android: backlog #21).
class LeaderboardTableScreen extends ConsumerWidget {
  const LeaderboardTableScreen({super.key, required this.board});

  final Leaderboard board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(leaderboardServiceProvider);
    return DefaultTabController(
      length: LeaderboardWeek.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(board.title),
          bottom: TabBar(tabs: [for (final w in LeaderboardWeek.values) Tab(key: Key('week-${w.name}'), text: w.label)]),
        ),
        body: service == null
            ? const _Message(key: Key('tableNotHere'), text: 'Leaderboards are on the iPhone (Game Center) for now.')
            : TabBarView(children: [for (final w in LeaderboardWeek.values) WeekTable(board: board, week: w)]),
        bottomNavigationBar: service == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                    key: const Key('openInGameCenter'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open in Game Center'),
                    onPressed: () => viewLeaderboard(context, service, board: board),
                  ),
                ),
              ),
      ),
    );
  }
}

/// One week's table, loaded when shown: loading, the table, no scores yet,
/// not signed in to Game Center, or no signal (each with Try again).
class WeekTable extends ConsumerStatefulWidget {
  const WeekTable({super.key, required this.board, required this.week});

  final Leaderboard board;
  final LeaderboardWeek week;

  @override
  ConsumerState<WeekTable> createState() => _WeekTableState();
}

enum _Failure { signedOut, noSignal }

class _WeekTableState extends ConsumerState<WeekTable> {
  LeaderboardTable? _table;
  _Failure? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(leaderboardServiceProvider);
    if (service == null) return;
    setState(() {
      _table = null;
      _failure = null;
    });
    LeaderboardTable? table;
    _Failure? failure;
    try {
      // Signs in to Game Center first, asking if needed.
      if (!await service.signIn()) throw const LeaderboardSignedOut();
      table = await service.loadTable(widget.board, widget.week);
    } on LeaderboardSignedOut {
      failure = _Failure.signedOut;
    } catch (_) {
      failure = _Failure.noSignal;
    }
    if (!mounted) return;
    setState(() {
      _table = table;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final retry = OutlinedButton(key: const Key('tableTryAgain'), onPressed: _load, child: const Text('Try again'));
    switch (_failure) {
      case _Failure.signedOut:
        return _Message(
          key: const Key('tableSignedOut'),
          text: "Sign in to Game Center (in the iPhone's Settings) to see the leaderboard.",
          action: retry,
        );
      case _Failure.noSignal:
        return _Message(
          key: const Key('tableFailed'),
          text: "Couldn't load the leaderboard. Check the signal and try again.",
          action: retry,
        );
      case null:
    }
    final table = _table;
    if (table == null) return const Center(child: CircularProgressIndicator());
    if (table.isEmpty) {
      return _Message(
        key: const Key('tableEmpty'),
        text: widget.week == LeaderboardWeek.thisWeek
            ? 'No scores yet this week. Post one at the end of a full session.'
            : 'No results for last week yet.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final e in table.entries) EntryRow(entry: e),
          if (table.meBelow) ...[
            const Divider(),
            EntryRow(entry: table.me!),
          ],
        ],
      ),
    );
  }
}

/// One row: the place, the nickname and the score; the player's own row
/// highlighted.
class EntryRow extends StatelessWidget {
  const EntryRow({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = entry.isMe;
    const digits = [FontFeature.tabularFigures()];
    return Container(
      key: Key(mine ? 'entryMe' : 'entry-${entry.rank}'),
      color: mine ? theme.colorScheme.primary.withValues(alpha: 0.15) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '${entry.rank}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: digits),
            ),
          ),
          Expanded(
            child: Text(
              mine ? '${entry.name} (you)' : entry.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: mine ? FontWeight.w700 : null),
            ),
          ),
          Text(
            '${entry.score}',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: digits),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}
