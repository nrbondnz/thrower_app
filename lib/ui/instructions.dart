import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../scoring/game_session.dart';
import '../scoring/target_model.dart';

/// One heading and its points on the Instructions screen.
class InstructionSection {
  const InstructionSection(this.heading, this.points);

  final String heading;
  final List<String> points;
}

/// What the instructions are for: the real thing, or the paper test target
/// (an A4 printout, with pens in Blu Tack standing in for knives).
enum InstructionTarget { realBoard, paper }

/// What players are told about setting up and playing. **Update this when the
/// app's behaviour changes** (see Common Tasks → Update the In-App
/// Instructions). Rule numbers come from [rules] and [target], so they can't
/// drift from the code; button names must match the screens.
List<InstructionSection> instructionSections(GameSession rules, TargetModel target,
    {InstructionTarget kind = InstructionTarget.realBoard}) {
  final paper = kind == InstructionTarget.paper;
  final ringScores = [for (final r in target.rings) '${r.score}'];
  final lineRing = switch (target.lineTouchRule) {
    LineTouchRule.higher => 'higher',
    LineTouchRule.lower => 'lower',
  };
  final n = rules.throwsPerRound;
  // What a throw and a knife are on the paper target.
  final knife = paper ? 'pen' : 'knife';
  final knives = paper ? 'pens' : 'knives';
  return [
    InstructionSection('Setting up', [
      if (paper) ...[
        'Never throw anything at the paper target. A grey or silver pen pushed into Blu Tack stands in for a knife.',
        'Print the A4 target at 100% (actual size). The black bar at the bottom should measure 100 mm.',
        'Tape it flat to a wall or door at about chest height, where no lamp or window shines on it.',
        'Put the phone somewhere stable, preferably on a tripod, about 50 cm from the paper and about 45° to one side, '
            'at the height of the target. That is how the app sees a real board from 2 m.',
      ] else ...[
        'The board should be about 75–85 cm across, with 5 painted rings in two alternating colours.',
        'Put the phone somewhere stable, preferably on a tripod, about 2 m from the board, about 45° to one side '
            'and at board height. It must be well out of the line of throw.',
      ],
      'The phone must not move during calibration or play: even a small knock shifts the picture and throws off '
          'the scores. If it does move, calibrate again.',
      'Hold it upright (portrait) with the whole target in the picture, as near the middle as you can: '
          'the app zooms in on the target, and can zoom closer when it is centred.',
      'Turn off auto-lock (screen timeout) while playing, so the screen stays on.',
      if (!paper) 'Even light helps. Avoid shadows moving across the board.',
    ]),
    const InstructionSection('Calibrating the target', [
      'Tap Calibrate target, then Find target. The camera zooms in on the target and the rings are outlined.',
      'If the outline is a little off, drag inside the rings to move it, or drag a white handle to reshape it. '
          'Only adjust when no one is throwing.',
      'Tap Lock target when the outline matches the rings.',
      'Calibrate again (Re-calibrate) whenever the phone or the target moves.',
    ]),
    InstructionSection('Playing a game', [
      'Tap Play. A game is ${rules.maxRounds} rounds of $n throws.',
      if (paper) ...[
        'A "throw" that sticks: press a pen in its Blu Tack onto the paper so it sticks out about 10 cm, then step '
            'out of the picture. The app waits for the target to settle, then shows the score in a yellow circle '
            'where the pen tip meets the paper.',
        'A bounce-out: wave a hand past the target without leaving anything, then step out of the picture.',
      ] else
        'Throw when the screen says Ready. The app waits for the board to settle, then shows the score in a '
            'yellow circle where the blade went in. A bounce-out shows a 0 beside the target.',
      'After $n throws the round is complete. Collect your $knives${paper ? '' : ' only when no one is throwing'}: '
          'the app sees someone at the target and starts the next round.',
      'Collecting early ends the round with fewer throws.',
      'After round ${rules.maxRounds} the game is over and shows your final total. Tap New game to play again.',
    ]),
    InstructionSection('Scoring', [
      'Rings score ${ringScores.first} for the centre, then ${ringScores.sublist(1, ringScores.length - 1).join(', ')}, '
          'and ${ringScores.last} for the outer ring. Outside the rings scores 0.',
      'A $knife touching the line between two rings scores the $lineRing ring.',
      'A bounce-out or a miss scores 0. A $knife that sticks and then falls out before it is collected scores 0.',
      'If the app saw a $knife stick but not where it went in, the throw shows "?" and scores 0.',
    ]),
    const InstructionSection('Resetting', [
      'Reset game (top right of Play) starts the game over. It asks first, because the scores are lost.',
    ]),
    // Quick draw (story-checkpoint-quick-draw). The safety points come from the
    // Review Agent's Safety Report on it (§7, two people throwing at once).
    InstructionSection('Quick draw', [
      if (paper)
        'Quick draw is for two real boards and two throwers. It is not played on the paper target.'
      else ...[
        'A duel: two throwers, one board each, side by side, throwing at the same time on "go". '
            'Tap Quick draw on the home screen. (Live test, then Quick draw, plays a recording of a real duel.)',
        'Put the phone on its stand behind the throwers, where it sees both boards: out of both lines of throw, '
            'not between the lanes, and out of reach of a backswing (at least 3 m back for axes, or as your venue says).',
        "On the screen, tap the centre (the bull) of Player 1's board, then Player 2's, then Lock boards. "
            'If an outline is wrong, tap Choose boards again.',
        'Choose and lock the boards before anyone throws.',
        'A third person, the starter, standing behind the throwers, taps Start. Throwers do not start their own '
            'duel: be at your line, ready, before Start is tapped.',
        'Five beeps, a light coming on with each, then a pause that changes every time, then the long beep: '
            'that is go. Check the beeps can be heard at the throwing lines.',
        'The first knife to stick wins. A bounce-out loses, and so does a knife before go (a false start). '
            'Both on the same frame is a draw. Times are measured from go to the knife reaching the board.',
        'The result shows in large type with a chime, a moment after the throws: read it from where you stand. '
            'No one needs to go to the phone during a duel.',
        'Collect your knives together, then tap Next duel. The boards stay locked.',
        "Quick draw is for experienced throwers only, under your venue's rules for throwing side by side. "
            'Use separate lanes, each thrower at their own line.',
        'Go only means start. It never means the lanes are clear, and neither do the chime and the result: '
            'no one goes forward until both throwers have finished and agree it is clear. Collect your knives together.',
        'Keep the phone out of both lines of throw and not between the lanes. Behind the throwers is fine.',
        'A bounce-out loses, so do not throw harder: speed comes from a clean release.',
        'After a false start, no one throws again until the knives are collected.',
        'Make sure everyone can hear the countdown.',
      ],
    ]),
    InstructionSection('Safety', [
      if (paper)
        'Nothing is ever thrown at the paper target: pens are placed by hand.'
      else ...[
        'Only go near the board, or the phone, when no one is throwing.',
        'The app cannot tell whether the lane is clear. "Someone is at the board" only means it saw movement there; '
            'it never means it is safe to approach.',
        'Keep the phone and tripod out of the line of throw.',
      ],
    ]),
    const InstructionSection('Reporting problems', [
      'Take a screenshot, then send it with TestFlight\'s Share Beta Feedback. Say what you expected and what happened.',
    ]),
  ];
}

/// How to set up and play: for a real board (the default), or the paper test
/// target.
class InstructionsScreen extends ConsumerStatefulWidget {
  const InstructionsScreen({super.key});

  @override
  ConsumerState<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends ConsumerState<InstructionsScreen> {
  var _kind = InstructionTarget.realBoard;

  @override
  Widget build(BuildContext context) {
    final sections = instructionSections(ref.watch(gameProvider), ref.watch(targetModelProvider), kind: _kind);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Instructions')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<InstructionTarget>(
              segments: const [
                ButtonSegment(value: InstructionTarget.realBoard, label: Text('Real board')),
                ButtonSegment(value: InstructionTarget.paper, label: Text('Paper target')),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.single),
            ),
            const SizedBox(height: 16),
            for (final section in sections) ...[
              Text(section.heading, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final point in section.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(point, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
