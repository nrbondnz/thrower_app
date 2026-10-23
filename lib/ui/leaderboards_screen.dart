import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../leaderboard/leaderboard_service.dart';
import '../providers.dart';
import 'post_score_panel.dart';
import 'theme/widgets.dart';

/// The Leaderboards tab (posting-from-history story, Nigel 2026-10-23: "put
/// online leaderboards" on the bar). One card per board; for now only
/// [Leaderboard.ranked3m], "3 m knives · 3 × 5". More will follow (a
/// friends', an area's or a club's board).
class LeaderboardsScreen extends ConsumerWidget {
  const LeaderboardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final service = ref.watch(leaderboardServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboards')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          for (final board in Leaderboard.values.where((b) => !b.test || ref.watch(testToolsProvider))) ...[
            ActionCard(
              key: Key('leaderboard-${board.name}'),
              icon: Icons.emoji_events_outlined,
              title: board.title,
              subtitle: board.about,
              onTap: service == null ? null : () => viewLeaderboard(context, service, board: board),
            ),
            const SizedBox(height: 12),
          ],
          if (service == null)
            Text(
              'Leaderboards are on the iPhone (Game Center) for now.',
              key: const Key('leaderboardsNotHere'),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          const SizedBox(height: 8),
          Text(
            'More to come: leaderboards for your friends, your area and your club.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
