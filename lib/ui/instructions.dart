import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../scoring/game_session.dart';
import '../scoring/game_type.dart';
import '../scoring/match.dart';
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
      'If Find target cannot find the rings (for example, rings painted with gaps in them), or finds the wrong '
          'board, tap Tap the board, then tap the middle of your board in the picture. Only do this when no one '
          'is throwing.',
      'Tap Lock target when the outline matches the rings.',
      'Calibrate again (Re-calibrate) whenever the phone or the target moves.',
    ]),
    InstructionSection('Playing a game', [
      'Tap Play, choose how many players (and, for two, how many targets) and how many rounds '
          '(${GameLengthNotifier.choices.join(', ')}), then Start. '
          'A game is ${rules.maxRounds} rounds of $n throws for each player.',
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
      'To stop sooner, tap Finish game (it asks first): the game ends with the rounds played so far, '
          'including a round in progress, and is kept in History.',
      // Named-players story (Nigel, 2026-10-19).
      'Before Start you can type each player\'s name (up to $maxNameLength letters); leave it blank for '
          '"Player 1" or "Player 2". The screens and History use the names, and Quick draw uses the same ones.',
      'The last names used are kept on this phone and filled in next time. They are sent nowhere, unless you '
          'sign in (see Your account).',
    ]),
    // Players-and-targets story (Nigel, 2026-10-16).
    InstructionSection('Two players on one target', [
      'Choose 2 players and 1 target. You take turns: Player 1 throws $n, the $knives are collected, then Player 2 '
          'throws $n. Player 1 starts every round.',
      'The screen says whose turn it is in large type. After $n throws it says to collect your $knives'
          '${paper ? '' : ' when no one is throwing'}, and then whose turn is next.',
      'Throw only on your turn, once the other player has collected their $knives and stepped back. '
          'Collecting early ends your turn with fewer throws.',
      'The game ends when both players have played round ${rules.maxRounds}. The higher total wins; '
          'equal totals are a draw.',
      'If you tap Finish game, the winner is decided on the rounds you have both played. '
          'A round only one of you has played is shown, but not counted.',
    ]),
    // Players-and-targets story, Task 3. The safety points are Quick draw's
    // (two people throwing at once; Review Agent §7).
    InstructionSection('Two players on two targets', [
      if (paper)
        'Two targets is for two real boards side by side. It is not played on the paper target.'
      else ...[
        'Choose 2 players and 2 targets: a board each, side by side, both throwing at the same time.',
        'Put the phone on its stand behind the throwers, where it sees both boards: out of both lines of throw, '
            'not between the lanes, and out of reach of a backswing.',
        "Before anyone throws, tap the centre of Player 1's board, then Player 2's, then Lock boards.",
        'If an outline doesn\'t fit its rings, drag it into place (inside to move it, a white handle to turn or '
            'stretch it), or tap Choose boards again.',
        // Adjust boards (backlog #10, 2026-10-19).
        'If a board or the phone is knocked during a game, tap Adjust boards when no one is throwing, drag the '
            'outline back, then Lock boards. Watching stops until you lock again; the scores stay.',
        'Each board scores for its own player. Use separate lanes, each thrower at their own line, '
            "under your venue's rules for throwing side by side.",
        'If you finish your round first, wait: the screen says to wait for the other player. '
            'Collect your knives together, when you have both finished and no one is throwing.',
        'The game ends when both players have played round ${rules.maxRounds}. The higher total wins; '
            'equal totals are a draw.',
      ],
    ]),
    InstructionSection('Scoring', [
      'Rings score ${ringScores.first} for the centre, then ${ringScores.sublist(1, ringScores.length - 1).join(', ')}, '
          'and ${ringScores.last} for the outer ring. Outside the rings scores 0.',
      'A $knife touching the line between two rings scores the $lineRing ring.',
      'A bounce-out or a miss scores 0. A $knife that sticks and then falls out before it is collected scores 0.',
      'If the app saw a $knife stick but not where it went in, the throw shows "?" and scores 0.',
      "This is KATTA scoring (the UK's Knife Axe and Tomahawk Throwing Association), the same as on the European "
          'and IKTHOF competition targets.',
    ]),
    // Score corrections story (Nigel, 2026-10-17). Going to the phone mid-game:
    // Review Agent §7.
    InstructionSection('Changing a score', [
      'Each throw of the round shows as a score under the picture. If a score is wrong, tap it and choose the right '
          'one, 0 to 5. A changed score shows in light blue with ✎, on the picture too.',
      'A $knife that misses the ${paper ? 'paper' : 'board'} altogether is usually not seen. Tap the next empty '
          'slot (–) and choose 0. If a $knife stuck and the app missed it, choose its score instead.',
      'For an earlier round, tap Rounds, then the round.',
      'Go to the phone only when no one is throwing, and tap lightly: a knock moves the picture. '
          'While a score is open nothing is watched, so nothing thrown then is scored.',
      'If the app says the phone may have moved, check the green rings still line up with the board. If not, '
          'calibrate again (on two targets, choose the boards again).',
    ]),
    InstructionSection('Precision and Three targets', [
      'Two more games, chosen under Which game? when you tap Play. For now they are scored by hand: the camera '
          'is not used.',
      'Precision: 7 rounds of 3 knives, each round from its own distance: '
          '${precisionDistances.map((d) => '$d').join(', ')} m. The screen shows the distance for the next knife.',
      'Three targets: three boards side by side. Each round, throw one knife at each target, 1, 2 then 3. '
          'Choose 3, 5 or 7 rounds.',
      'With two players, take turns: Player 1 throws 3 knives and collects them, then Player 2.',
      'After each knife, tap its score on the score pad: 5 to 1, or Miss. Tap a score in a round to change it.',
      'Only go to the phone to score when no one is throwing, or have someone who is not throwing keep score. '
          'Never stand in the lane to use the phone.',
      'The highest total wins. Finish game ends it early, and every game is kept in History.',
    ]),
    const InstructionSection('Resetting', [
      'Reset game (top right of Play) starts the game over. It asks first, because the scores are lost.',
    ]),
    // Game-history story (Nigel, 2026-10-16).
    const InstructionSection('History', [
      'Each game of Play is kept when it finishes. Tap History on the home screen to see them, newest first, '
          'and tap a game to see every round. Games played on a Live test recording are marked Live test.',
      'A game that is reset or left before it finishes is not kept.',
      'To remove a game, open it and tap the bin. Clear history removes them all; it asks first.',
      'The history stays on this phone: the app sends it nowhere unless you sign in (see Your account). '
          'Deleting the app deletes the copy on this phone.',
    ]),
    // App user accounts story (2026-10-19): optional; backup; Delete account
    // (Apple 5.1.1(v)).
    const InstructionSection('Your account', [
      'An account is optional: everything works without one. Tap the person icon on the home screen to create '
          'one (with your email) or sign in.',
      'While you are signed in, your History and player names are backed up to your account, and come back '
          'when you sign in on another phone. Backing up waits for a signal; your games are always kept on the '
          'phone first.',
      'To delete your account, open it and tap Delete account (it asks first). The account and its backup are '
          'deleted; the games and names on this phone stay.',
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
        "On the screen, tap the centre (the bull) of Player 1's board, then Player 2's, then Lock boards.",
        'If an outline doesn\'t fit its rings, drag it into place (inside to move it, a white handle to turn or '
            'stretch it), or tap Choose boards again.',
        'Between rounds, Adjust boards unlocks them to fix an outline (only when no one is throwing); the match '
            'carries on.',
        'Choose and lock the boards before anyone throws. Tap Names to change the throwers\' names (the same '
            'names as Play).',
        'A third person, the starter, standing behind the throwers, taps Start. Throwers do not start their own '
            'duel: be at your line, ready, before Start is tapped.',
        'Five beeps, a light coming on with each, then a pause that changes every time, then the long beep: '
            'that is go. Check the beeps can be heard at the throwing lines.',
        'A match is three rounds. In each round the first knife to stick wins. A bounce-out loses, and so does a '
            'knife before go (a false start). If both stick on the same frame, the higher score wins; the same score '
            'is a drawn round. Times are measured from go to the knife reaching the board.',
        'All three rounds are thrown, even when one thrower has already won two. Whoever wins more rounds wins the '
            'match. If it is level after three, extra rounds are thrown, one at a time, until one is won.',
        'To end a match early, the starter taps Finish match: it ends on the rounds won so far, and level is a draw.',
        "Each round's result shows in large type with a chime, a moment after the throws, with the match so far: "
            'read it from where you stand. No one needs to go to the phone during a round.',
        'Between rounds, collect your knives together; then the starter taps Next round. The boards stay locked.',
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
        'With two players, "Player 2\'s turn", "Wait for Player 2" and "Collect your knives" only follow the scores. '
            'They never mean the lane is clear: look before you go forward.',
        'Keep the phone and tripod out of the line of throw.',
        'Changing a score means going to the phone: only when no one is throwing, and with two targets only when '
            'both have finished. Leave the phone where it is; never move it closer to reach it.',
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
    final sections = instructionSections(ref.watch(gameProvider).players.first, ref.watch(targetModelProvider), kind: _kind);
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
