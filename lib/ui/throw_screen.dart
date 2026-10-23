import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'app_shell.dart';
import 'live_quick_draw_screen.dart';
import 'play_setup_screen.dart';
import 'post_score_panel.dart';
import 'theme/widgets.dart';

/// The Throw tab: a card for each way to throw
/// (docs/thrower/AppDesign/Navigation and Structure.md → Throw).
class ThrowScreen extends ConsumerWidget {
  const ThrowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(leaderboardServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Throw')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ActionCard(
            key: const Key('throwRounds'),
            icon: Icons.track_changes,
            title: 'Rounds',
            subtitle: 'Rounds of 3 knives, 1 or 2 throwers. Scoring, Precision, Three targets or Ranked.',
            onTap: () => openScreen(context, ref, const PlaySetupScreen()),
          ),
          const SizedBox(height: 12),
          ActionCard(
            key: const Key('throwQuickDraw'),
            icon: Icons.bolt,
            title: 'Quick draw',
            subtitle: 'Two throwers, head to head on a start signal.',
            onTap: () => openScreen(context, ref, const LiveQuickDrawScreen()),
          ),
          if (leaderboard != null) ...[
            const SizedBox(height: 12),
            ActionCard(
              key: const Key('throwLeaderboard'),
              icon: Icons.emoji_events_outlined,
              title: 'Leaderboard',
              subtitle: 'Ranked: 5 × 3 at 3 m, on Game Center. Starts again each week.',
              onTap: () => viewLeaderboard(context, leaderboard),
            ),
          ],
        ],
      ),
    );
  }
}
