import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../scoring/match.dart';
import 'play_screen.dart';

/// The screen after Home → Play (and Live test → Play): **how many players**,
/// 1 or 2, and for 2, **one target** (taking turns) or **two** (throwing at
/// the same time) (Nigel, 2026-10-16). Starts with the last choice. **Start**
/// keeps a game in progress if the choice is the same, and starts a new one
/// if it changed.
class PlaySetupScreen extends ConsumerStatefulWidget {
  const PlaySetupScreen({super.key});

  /// The modes Play can run so far (players-and-targets story: two players
  /// on one target comes in Task 2, on two targets in Task 3).
  static const playable = {PlayMode.solo};

  @override
  ConsumerState<PlaySetupScreen> createState() => _PlaySetupScreenState();
}

class _PlaySetupScreenState extends ConsumerState<PlaySetupScreen> {
  late var _players = ref.read(playModeProvider).players;

  /// With 2 players: one target or two.
  late var _targets = ref.read(playModeProvider).targets;

  PlayMode get _mode => _players == 1
      ? PlayMode.solo
      : _targets == 1
          ? PlayMode.sharedTarget
          : PlayMode.twoTargets;

  void _start() {
    ref.read(playModeProvider.notifier).choose(_mode);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PlayScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = _mode;
    final playable = PlaySetupScreen.playable.contains(mode);
    return Scaffold(
      appBar: AppBar(title: const Text('Play')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('How many players?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              key: const Key('playPlayers'),
              segments: const [
                ButtonSegment(value: 1, label: Text('1 player')),
                ButtonSegment(value: 2, label: Text('2 players')),
              ],
              selected: {_players},
              onSelectionChanged: (s) => setState(() => _players = s.single),
            ),
            if (_players == 2) ...[
              const SizedBox(height: 24),
              Text('How many targets?', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                key: const Key('playTargets'),
                segments: const [
                  ButtonSegment(value: 1, label: Text('1 target')),
                  ButtonSegment(value: 2, label: Text('2 targets')),
                ],
                selected: {_targets == 2 ? 2 : 1},
                onSelectionChanged: (s) => setState(() => _targets = s.single),
              ),
            ],
            const SizedBox(height: 16),
            Text(modeDescription(mode), key: const Key('playModeDescription')),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('playStart'),
              onPressed: playable ? _start : null,
              child: const Text('Start'),
            ),
            if (!playable) ...[
              const SizedBox(height: 8),
              Text('Coming soon.', key: const Key('playComingSoon'), style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// What each way of playing means, under the choices.
String modeDescription(PlayMode mode) => switch (mode) {
      PlayMode.solo => 'Rounds of 3 throws on one target.',
      PlayMode.sharedTarget => 'Take turns on one target: Player 1 throws 3 knives and collects them, '
          'then Player 2. Player 1 starts every round.',
      PlayMode.twoTargets => 'A target each, throwing at the same time. Each thrower needs their own lane, '
          'and you both collect your knives together, when you have both finished.',
    };
