import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/main.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/ui/instructions.dart';

/// Every point of every section, as one string.
String allText(GameSession rules, TargetModel target, {InstructionTarget kind = InstructionTarget.realBoard}) =>
    [for (final s in instructionSections(rules, target, kind: kind)) ...[s.heading, ...s.points]].join('\n');

void main() {
  final text = allText(const GameSession(), TargetModel.katta());
  final paper = allText(const GameSession(), TargetModel.katta(), kind: InstructionTarget.paper);

  test('states the game length from the rules: 9 rounds of 3 throws', () {
    expect(text, contains('A game is 9 rounds of 3 throws for each player.'));
    expect(text, contains('After round 9 the game is over'));
  });

  test('follows the rules if they change', () {
    final changed = allText(const GameSession(maxRounds: 5, throwsPerRound: 2), TargetModel.katta());
    expect(changed, contains('A game is 5 rounds of 2 throws for each player.'));
    expect(changed, contains('After 2 throws the round is complete.'));
  });

  test('ring scores come from the target model', () {
    expect(text, contains('Rings score 5 for the centre, then 4, 3, 2, and 1 for the outer ring.'));
  });

  test('the line-touch rule comes from the target model', () {
    expect(text, contains('scores the higher ring'));
    expect(allText(const GameSession(), TargetModel.katta(lineTouchRule: LineTouchRule.lower)),
        contains('scores the lower ring'));
  });

  test('asks for a stable phone, preferably on a tripod (Nigel, 2026-10-09)', () {
    expect(text, contains('preferably on a tripod'));
    expect(text, contains('calibrate again'));
  });

  test('says the game length can be chosen: 3, 5 or 9 rounds', () {
    expect(text, contains('and how many rounds (3, 5, 9), then Start.'));
  });

  test('says the app cannot tell whether the lane is clear', () {
    expect(text, contains('cannot tell whether the lane is clear'));
    expect(text, contains('it never means it is safe to approach'));
  });

  test("says the two-player prompts only follow the scores, never that the lane is clear", () {
    expect(text, contains('"Collect your knives" only follow the scores. They never mean the lane is clear'));
  });

  test('has the sections testers need, in order', () {
    expect([for (final s in instructionSections(const GameSession(), TargetModel.katta())) s.heading], [
      'Setting up',
      'Calibrating the target',
      'Playing a game',
      'Two players on one target',
      'Two players on two targets',
      'Scoring',
      'Changing a score',
      'Precision and Three targets',
      'Ranked games',
      'Resetting',
      'History',
      'Your account',
      'Quick draw',
      'Safety',
      'Reporting problems',
    ]);
  });

  test('Finish game: ends with the rounds played; two players judged on rounds both played', () {
    expect(text, contains('tap Finish game (it asks first): the game ends with the rounds played so far'));
    expect(text, contains('the winner is decided on the rounds you have both played'));
  });

  test('Changing a score: tap a score, 0 to 5; a miss is an empty slot and 0; earlier rounds', () {
    expect(text, contains('If a score is wrong, tap it and choose the right one, 0 to 5.'));
    expect(text, contains('A knife that misses the board altogether is usually not seen. Tap the next empty slot'));
    expect(text, contains('tap Rounds, then the round'));
    expect(paper, contains('A pen that misses the paper altogether'));
  });

  test('Changing a score: only when no one is throwing, tap lightly, nothing scored meanwhile, re-calibrate if moved', () {
    expect(text, contains('Go to the phone only when no one is throwing, and tap lightly'));
    expect(text, contains('While a score is open nothing is watched'));
    expect(text, contains('If the app says the phone may have moved'));
    expect(text, contains('Changing a score means going to the phone: only when no one is throwing'));
    expect(text, contains('never move it closer to reach it'));
  });

  test('History: finished games only, where to find them, delete and clear, kept on the phone', () {
    expect(text, contains('Each game of Play is kept when it finishes. Tap History on the home screen'));
    expect(text, contains('reset or left before it finishes is not kept'));
    expect(text, contains('Clear history removes them all; it asks first.'));
    expect(text, contains('The history stays on this phone: the app sends it nowhere unless you sign in'));
  });

  test('two players on two targets: own lanes, phone out of both lines, collect together', () {
    expect(text, contains('Use separate lanes, each thrower at their own line'));
    expect(text, contains('out of both lines of throw, not between the lanes'));
    expect(text, contains('Collect your knives together, when you have both finished and no one is throwing'));
    expect(paper, contains('It is not played on the paper target.'));
  });

  test('two players on one target: take turns, throw only after the other has collected', () {
    expect(text, contains('Player 1 starts every round'));
    expect(text, contains('once the other player has collected their knives and stepped back'));
    expect(text, contains('collect your knives when no one is throwing, and then whose turn is next'));
    expect(paper, contains('collect your pens, and then whose turn is next'));
  });

  testWidgets('Home → Instructions opens the instructions', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ThrowerApp()));
    await tester.tap(find.text('Instructions'));
    await tester.pumpAndSettle();
    expect(find.byType(InstructionsScreen), findsOneWidget);
    expect(find.text('Setting up'), findsOneWidget);
    expect(find.textContaining('preferably on a tripod'), findsOneWidget);
  });

  group('real board (the default)', () {
    test('sets up at 2 m on a board, out of the line of throw', () {
      expect(text, contains('about 2 m from the board'));
      expect(text, contains('well out of the line of throw'));
    });

    test('says nothing about paper or Blu Tack', () {
      expect(text, isNot(contains('Blu Tack')));
      expect(text, isNot(contains('paper')));
    });
  });

  test('names KATTA scoring', () {
    expect(text, contains("This is KATTA scoring (the UK's Knife Axe and Tomahawk Throwing Association)"));
  });

  // Named-players story (Nigel, 2026-10-19).
  test('naming players: optional, remembered on the phone, sent nowhere', () {
    expect(text, contains("Before Start you can type each player's name (up to 16 letters); leave it blank for "
        '"Player 1" or "Player 2".'));
    expect(text, contains('The last names used are kept on this phone and filled in next time. They are sent nowhere, '
        'unless you sign in'));
    expect(text, contains("Tap Names to change the throwers' names (the same names as Play)."));
  });

  // Backlog #10 (2026-10-19): drag an outline into place; Adjust boards.
  test('two boards: drag an outline into place, or Adjust boards later, only when no one is throwing', () {
    expect(text, contains("If an outline doesn't fit its rings, drag it into place (inside to move it, a white handle"));
    expect(text, contains('If a board or the phone is knocked during a game, tap Adjust boards when no one is throwing'));
    expect(text, contains('Between rounds, Adjust boards unlocks them to fix an outline (only when no one is throwing)'));
  });

  // App user accounts story (2026-10-19).
  test("the account: optional, backs up History and names, Delete account keeps the phone's games", () {
    expect(text, contains('An account is optional: everything works without one.'));
    expect(text, contains('your History and player names are backed up to your account'));
    expect(text, contains('tap Delete account (it asks first)'));
    expect(text, contains('the games and names on this phone stay'));
  });

  group('Quick draw (real board)', () {
    test('how to choose the boards and play, with the button names on the screen', () {
      expect(text, contains("On the screen, tap the centre (the bull) of Player 1's board, then Player 2's, then Lock boards."));
      expect(text, contains('tap Choose boards again'));
      expect(text, contains('Tap Quick draw on the home screen.'));
      expect(text, contains('then the starter taps Next round.'));
    });

    // The match (Nigel's brother, 2026-10-19; story-checkpoint-quick-draw-match).
    test('a match of three rounds: the round rule with the score tie-break', () {
      expect(text, contains('A match is three rounds. In each round the first knife to stick wins.'));
      expect(text, contains('If both stick on the same frame, the higher score wins; the same score is a drawn round.'));
    });

    test('all three rounds are thrown; level means extra rounds; Finish match ends it early', () {
      expect(text, contains('All three rounds are thrown, even when one thrower has already won two.'));
      expect(text, contains('extra rounds are thrown, one at a time, until one is won'));
      expect(text, contains('the starter taps Finish match: it ends on the rounds won so far, and level is a draw'));
    });

    // The Safety Report on the live Quick draw (Tasks 3–5, 2026-10-15).
    test('a starter behind the throwers taps Start; throwers never start their own duel', () {
      expect(text, contains('A third person, the starter, standing behind the throwers, taps Start.'));
      expect(text, contains('Throwers do not start their own duel: be at your line, ready, before Start is tapped.'));
    });

    test('the phone and starter stand out of reach of a backswing', () {
      expect(text, contains('out of reach of a backswing (at least 3 m back for axes, or as your venue says)'));
    });

    test('neither the chime nor the result means the lanes are clear', () {
      expect(text, contains('It never means the lanes are clear, and neither do the chime and the result'));
    });

    test('the beeps must be heard at the throwing lines', () {
      expect(text, contains('Check the beeps can be heard at the throwing lines.'));
    });

    test('the start signal: five beeps, a pause that changes, then the long beep is go', () {
      expect(text, contains('Five beeps, a light coming on with each, then a pause that changes every time, then the long beep: that is go.'));
    });

    test('the winning rule: first to stick; bounce-out and false start lose', () {
      expect(text, contains('In each round the first knife to stick wins. A bounce-out loses, and so does a knife before go (a false start).'));
    });

    // The Safety Report on Quick draw (Task 1 of story-checkpoint-quick-draw).
    test('go never means the lanes are clear; no one goes forward until both have finished', () {
      expect(text, contains('It never means the lanes are clear'));
      expect(text, contains('no one goes forward until both throwers have finished'));
    });

    test('experienced throwers, venue rules, separate lanes', () {
      expect(text, contains('experienced throwers only'));
      expect(text, contains('Use separate lanes'));
    });

    test('boards are chosen before anyone throws; no one goes to the phone after that', () {
      expect(text, contains('Choose and lock the boards before anyone throws.'));
      expect(text, contains('Or tap Draw round the boards first'));
      expect(text, contains('Strict mode: a score can only be changed to 0'));
      expect(text, contains('Only a full game of 5 rounds can be posted.'));
      expect(text, contains('ends with Post score and View leaderboard'));
      expect(text, contains('Once posted, the game\'s scores can no longer be changed.'));
      expect(text, contains('it gets four corners, which you can drag into place'));
      expect(text, contains('never at the boards; only when no one is throwing'));
      expect(text, contains('read it from where you stand. No one needs to go to the phone during a round.'));
    });

    test('the phone out of both lines of throw and not between the lanes', () {
      expect(text, contains('Keep the phone out of both lines of throw and not between the lanes.'));
    });

    test("don't throw harder; no re-throw after a false start; the countdown must be heard", () {
      expect(text, contains('do not throw harder'));
      expect(text, contains('After a false start, no one throws again until the knives are collected.'));
      expect(text, contains('hear the countdown'));
    });
  });

  group('paper target', () {
    test('Quick draw is not played on paper', () {
      expect(paper, contains('It is not played on the paper target.'));
      expect(paper, isNot(contains('Lock boards')));
    });

    test('never throw at it; pens in Blu Tack stand in for knives', () {
      expect(paper, contains('Never throw anything at the paper target.'));
      expect(paper, contains('pen pushed into Blu Tack'));
    });

    test('print at 100% and check the 100 mm bar', () {
      expect(paper, contains('Print the A4 target at 100% (actual size).'));
      expect(paper, contains('should measure 100 mm'));
    });

    test('phone 50 cm away, still preferably on a tripod', () {
      expect(paper, contains('about 50 cm from the paper'));
      expect(paper, contains('preferably on a tripod'));
    });

    test('explains a placed pen and a hand-wave bounce-out', () {
      expect(paper, contains('press a pen in its Blu Tack onto the paper'));
      expect(paper, contains('A bounce-out: wave a hand past the target'));
      expect(paper, contains('A pen touching the line between two rings scores the higher ring.'));
    });

    test('the same game rules and sections as the real board', () {
      expect(paper, contains('A game is 9 rounds of 3 throws for each player.'));
      expect([for (final s in instructionSections(const GameSession(), TargetModel.katta(), kind: InstructionTarget.paper)) s.heading],
          [for (final s in instructionSections(const GameSession(), TargetModel.katta())) s.heading]);
    });
  });

  testWidgets('opens on Real board; Paper target switches the text', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: InstructionsScreen())));
    expect(find.textContaining('about 2 m from the board'), findsOneWidget);
    await tester.tap(find.text('Paper target'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Never throw anything at the paper target'), findsOneWidget);
    expect(find.textContaining('about 2 m from the board'), findsNothing);
  });

  testWidgets('the last section can be scrolled to', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: InstructionsScreen())));
    await tester.scrollUntilVisible(find.text('Reporting problems'), 300);
    expect(find.text('Reporting problems'), findsOneWidget);
  });

  // More-game-types story (2026-10-20).
  test('explains Precision with its distances, and Three targets', () {
    expect(text, contains('Precision: 7 rounds of 3 knives'));
    expect(text, contains('3, 5, 7, 3, 4, 5, 7 m'));
    expect(text, contains('throw one knife at each target'));
  });

  test('scoring by hand: only when no one is throwing, never in the lane', () {
    expect(text, contains('Only go to the phone to score when no one is throwing'));
    expect(text, contains('Never stand in the lane to use the phone.'));
  });

  // Gapped-rings story (2026-10-21).
  test('calibrating: Tap the board when Find target cannot find the rings', () {
    expect(text, contains('tap Tap the board, then tap the middle of your board'));
  });
}
