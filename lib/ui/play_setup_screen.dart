import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../scoring/match.dart';
import 'play_screen.dart';
import 'two_target_play_screen.dart';

/// The screen after Home → Play (and Live test → Play): **how many players**,
/// 1 or 2, and for 2, **one target** (taking turns) or **two** (throwing at
/// the same time); and **how many rounds**, 3, 5 or 9 (Nigel, 2026-10-16);
/// and, optionally, **each player's name** (named-players story, 2026-10-19:
/// filled in with the last names used; blank is "Player N"). Starts with the
/// last choice. **Start** keeps a game in progress if the choice is the
/// same (renaming it if the names changed), and starts a new one if it
/// changed.
class PlaySetupScreen extends ConsumerStatefulWidget {
  const PlaySetupScreen({super.key});

  @override
  ConsumerState<PlaySetupScreen> createState() => _PlaySetupScreenState();
}

class _PlaySetupScreenState extends ConsumerState<PlaySetupScreen> {
  late var _players = ref.read(playModeProvider).players;

  /// With 2 players: one target or two.
  late var _targets = ref.read(playModeProvider).targets;

  late var _rounds = ref.read(gameLengthProvider);

  /// Each seat's name field, filled with the names kept on the phone.
  late final _names = [
    for (final n in ref.read(playerNamesProvider)) TextEditingController(text: n ?? ''),
  ];

  /// A name has been typed: the kept names, if they load late, don't
  /// replace it.
  var _typed = false;

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  PlayMode get _mode => _players == 1
      ? PlayMode.solo
      : _targets == 1
          ? PlayMode.sharedTarget
          : PlayMode.twoTargets;

  void _start() {
    final mode = _mode;
    ref.read(playModeProvider.notifier).choose(mode);
    ref.read(gameLengthProvider.notifier).choose(_rounds);
    ref.read(playerNamesProvider.notifier).set([for (final c in _names) c.text]);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => mode == PlayMode.twoTargets ? const TwoTargetPlayScreen() : const PlayScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerNamesProvider, (_, names) {
      if (_typed) return;
      for (final (i, c) in _names.indexed) {
        c.text = names[i] ?? '';
      }
    });
    final theme = Theme.of(context);
    final mode = _mode;
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
            const SizedBox(height: 24),
            Text(_players == 1 ? 'Name (optional)' : 'Names (optional)', style: theme.textTheme.titleMedium),
            for (var i = 0; i < _players; i++)
              TextField(
                key: Key('playName$i'),
                controller: _names[i],
                decoration: InputDecoration(hintText: playerNumber(i)),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(maxNameLength)],
                onChanged: (_) => _typed = true,
              ),
            const SizedBox(height: 24),
            Text('How many rounds?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              key: const Key('playRounds'),
              segments: [
                for (final n in GameLengthNotifier.choices) ButtonSegment(value: n, label: Text('$n')),
              ],
              selected: {_rounds},
              onSelectionChanged: (s) => setState(() => _rounds = s.single),
            ),
            const SizedBox(height: 16),
            Text(modeDescription(mode), key: const Key('playModeDescription')),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('playStart'),
              onPressed: _start,
              child: const Text('Start'),
            ),
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
