import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../scoring/game_type.dart';
import '../scoring/match.dart';
import 'play_screen.dart';
import 'score_pad_screen.dart';
import 'two_target_play_screen.dart';

/// The screen after Home → Play (and Live test → Play): **how many players**,
/// 1 or 2, and for 2, **one target** (taking turns) or **two** (throwing at
/// the same time); and **how many rounds**, 3, 5 or 9 (Nigel, 2026-10-16);
/// and, optionally, **each player's name** (named-players story, 2026-10-19:
/// filled in with the last names used; blank is "Player N"). First, **which
/// game** (more-game-types story, 2026-10-20): Scoring, or Precision or
/// Three targets, which are scored by hand on a score pad, on one target
/// (two players take turns), with their own lengths. Starts with the last
/// choice. **Start** keeps a game in progress if the choice is the
/// same (renaming it if the names changed), and starts a new one if it
/// changed. **Ranked** (story-checkpoint-game-center-scores, 2026-10-22) is
/// one player, 5 rounds, and Start waits for the thrower to confirm they
/// throw from 3 m.
class PlaySetupScreen extends ConsumerStatefulWidget {
  const PlaySetupScreen({super.key});

  @override
  ConsumerState<PlaySetupScreen> createState() => _PlaySetupScreenState();
}

class _PlaySetupScreenState extends ConsumerState<PlaySetupScreen> {
  /// Playing a Live test recording: Ranked isn't offered (a recording's
  /// score is not the thrower's).
  late final _onRecording = ref.read(recordingChoiceProvider) != null;

  /// The game types offered here.
  late final _types = [
    for (final t in GameType.values)
      if (!(_onRecording && t == GameType.ranked)) t,
  ];

  late var _type = _types.contains(ref.read(gameTypeProvider)) ? ref.read(gameTypeProvider) : GameType.scoring;

  late var _players = ref.read(playModeProvider).players;

  /// With 2 players: one target or two.
  late var _targets = ref.read(playModeProvider).targets;

  late var _rounds = _fit(ref.read(gameLengthProvider));

  /// Ranked: the thrower has confirmed the distance.
  var _distanceConfirmed = false;

  bool get _ranked => _type == GameType.ranked;

  /// [rounds] if [_type] offers it, else the type's usual length.
  int _fit(int rounds) => _type.roundChoices.contains(rounds) ? rounds : _type.defaultRounds;

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

  PlayMode get _mode => _players == 1 || _ranked
      ? PlayMode.solo
      : _targets == 1 || _type.handScored
          ? PlayMode.sharedTarget
          : PlayMode.twoTargets;

  void _start() {
    final mode = _mode;
    final type = _type;
    ref.read(gameTypeProvider.notifier).choose(type);
    ref.read(playModeProvider.notifier).choose(mode);
    ref.read(gameLengthProvider.notifier).choose(_rounds);
    ref.read(playerNamesProvider.notifier).set([for (final c in _names) c.text]);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => type.handScored
          ? const ScorePadScreen()
          : mode == PlayMode.twoTargets
              ? const TwoTargetPlayScreen()
              : const PlayScreen(),
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
            Text('Which game?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              key: const Key('playGame'),
              spacing: 8,
              children: [
                for (final t in _types)
                  ChoiceChip(
                    key: Key('playGame-${t.name}'),
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() {
                      _type = t;
                      _rounds = _fit(_rounds);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (_ranked)
              CheckboxListTile(
                key: const Key('playRankedDistance'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _distanceConfirmed,
                onChanged: (v) => setState(() => _distanceConfirmed = v ?? false),
                title: const Text("I'm throwing from $rankedDistance m"),
                subtitle: const Text('Measured from the board to the throwing line.'),
              )
            else ...[
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
            ],
            if (_players == 2 && !_type.handScored && !_ranked) ...[
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
            Text(mode.players == 1 ? 'Name (optional)' : 'Names (optional)', style: theme.textTheme.titleMedium),
            for (var i = 0; i < mode.players; i++)
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
            if (_type.roundChoices.length > 1)
              SegmentedButton<int>(
                key: const Key('playRounds'),
                segments: [
                  for (final n in _type.roundChoices) ButtonSegment(value: n, label: Text('$n')),
                ],
                selected: {_rounds},
                onSelectionChanged: (s) => setState(() => _rounds = s.single),
              )
            else
              Text('${_type.defaultRounds} rounds', key: const Key('playRoundsFixed')),
            const SizedBox(height: 16),
            Text(_type.handScored || _ranked ? typeDescription(_type, mode) : modeDescription(mode),
                key: const Key('playModeDescription')),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('playStart'),
              onPressed: _ranked && !_distanceConfirmed ? null : _start,
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }
}

/// What Precision, Three targets and Ranked mean, under the choices.
String typeDescription(GameType type, PlayMode mode) {
  final turns = mode == PlayMode.sharedTarget
      ? ' Take turns: Player 1 throws 3 knives and collects them, then Player 2.'
      : '';
  final how = switch (type) {
    GameType.precision => '7 rounds of 3 knives, each round from its own distance: '
        '${precisionDistances.map((d) => '$d').join(', ')} m.',
    GameType.threeTargets => 'Three targets side by side: each round, one knife at each target, in order.',
    GameType.ranked => '5 rounds of 3 knives from 3 m, one player, scored by the camera. Scores can only be '
        'changed to a bounce-out (0). A full game can be posted to the leaderboard.',
    GameType.scoring => '',
  };
  return type.handScored ? '$how$turns Score each knife by hand on the score pad.' : '$how$turns';
}

/// What each way of playing means, under the choices.
String modeDescription(PlayMode mode) => switch (mode) {
      PlayMode.solo => 'Rounds of 3 throws on one target.',
      PlayMode.sharedTarget => 'Take turns on one target: Player 1 throws 3 knives and collects them, '
          'then Player 2. Player 1 starts every round.',
      PlayMode.twoTargets => 'A target each, throwing at the same time. Each thrower needs their own lane, '
          'and you both collect your knives together, when you have both finished.',
    };
