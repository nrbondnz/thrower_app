import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/game_record.dart';
import '../history/throw_stats.dart';
import '../providers.dart';
import 'app_shell.dart';
import 'history_screen.dart';
import 'live_quick_draw_screen.dart';
import 'play_setup_screen.dart';
import 'theme/widgets.dart';

/// The Home tab (app-design story, docs/thrower/AppDesign/Home Screen.md):
/// the hero (the target, THROWER, what the app does), the last session,
/// **Start throwing**, and cards for the ways to throw. The tools are under
/// Setup.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onShowHistory});

  /// Tapping the last session: the History tab.
  final VoidCallback? onShowHistory;

  /// The hero's line under THROWER.
  static const tagline = 'Every throw seen. Every score counted.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final games = ref.watch(keptGamesProvider).value;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const Center(child: TargetMark(size: 88)),
            const SizedBox(height: 12),
            Text(
              'THROWER',
              key: const Key('homeTitle'),
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 6),
            ),
            const SizedBox(height: 4),
            Text(
              tagline,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SectionHeading('Last session'),
            LastSessionCard(games: games, onTap: onShowHistory),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton(
                key: const Key('homeStart'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
                onPressed: () => openScreen(context, ref, const PlaySetupScreen()),
                child: const Text('START THROWING'),
              ),
            ),
            const SectionHeading('Throwing types'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ActionCard(
                    key: const Key('homeRounds'),
                    icon: Icons.track_changes,
                    title: 'Rounds',
                    subtitle: '1 or 2 throwers',
                    onTap: () => openScreen(context, ref, const PlaySetupScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ActionCard(
                    key: const Key('homeQuickDraw'),
                    icon: Icons.bolt,
                    title: 'Quick draw',
                    subtitle: 'Head to head',
                    onTap: () => openScreen(context, ref, const LiveQuickDrawScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The last session kept on the phone: when, what kind, and its numbers
/// (one thrower: points, per knife, 5s; two: each thrower's points).
/// Before the first: "Your sessions will show here."
class LastSessionCard extends StatelessWidget {
  const LastSessionCard({super.key, required this.games, this.onTap});

  /// The kept sessions, newest first; null while they're read.
  final List<GameRecord>? games;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = games?.where((g) => !g.liveTest && !g.test).firstOrNull;
    return Card(
      key: const Key('homeLastSession'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: last == null ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: last == null
              ? Text(
                  games == null ? '' : 'Your sessions will show here.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${last.type.label} · ${whenText(last.finishedAt)}',
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    StatRow(lastSessionTiles(last)),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'See history →',
                        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The last session's numbers: one thrower's points, per knife and 5s (the
/// knife stats only once each knife is kept); two throwers' points each.
List<StatTile> lastSessionTiles(GameRecord game) {
  if (game.players.length > 1) {
    return [
      for (var p = 0; p < game.players.length; p++) StatTile(value: '${game.countedTotals[p]}', label: game.nameOf(p)),
    ];
  }
  final stats = ThrowStats.of([game]);
  return [
    StatTile(value: '${game.totals.single}', label: 'Points'),
    if (game.knives != null) ...[
      StatTile(value: perKnifeText(stats), label: 'Per knife'),
      StatTile(value: '${stats.fives}', label: '5s'),
    ],
  ];
}
