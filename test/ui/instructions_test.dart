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
  final text = allText(const GameSession(), TargetModel.ikthof());
  final paper = allText(const GameSession(), TargetModel.ikthof(), kind: InstructionTarget.paper);

  test('states the game length from the rules: 9 rounds of 3 throws', () {
    expect(text, contains('A game is 9 rounds of 3 throws.'));
    expect(text, contains('After round 9 the game is over'));
  });

  test('follows the rules if they change', () {
    final changed = allText(const GameSession(maxRounds: 5, throwsPerRound: 2), TargetModel.ikthof());
    expect(changed, contains('A game is 5 rounds of 2 throws.'));
    expect(changed, contains('After 2 throws the round is complete.'));
  });

  test('ring scores come from the target model', () {
    expect(text, contains('Rings score 5 for the centre, then 4, 3, 2, and 1 for the outer ring.'));
  });

  test('the line-touch rule comes from the target model', () {
    expect(text, contains('scores the higher ring'));
    expect(allText(const GameSession(), TargetModel.ikthof(lineTouchRule: LineTouchRule.lower)),
        contains('scores the lower ring'));
  });

  test('asks for a stable phone, preferably on a tripod (Nigel, 2026-10-09)', () {
    expect(text, contains('preferably on a tripod'));
    expect(text, contains('calibrate again'));
  });

  test('says the app cannot tell whether the lane is clear', () {
    expect(text, contains('cannot tell whether the lane is clear'));
    expect(text, contains('it never means it is safe to approach'));
  });

  test('has the sections testers need, in order', () {
    expect([for (final s in instructionSections(const GameSession(), TargetModel.ikthof())) s.heading], [
      'Setting up',
      'Calibrating the target',
      'Playing a game',
      'Scoring',
      'Resetting',
      'Quick draw',
      'Safety',
      'Reporting problems',
    ]);
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

  group('Quick draw (real board)', () {
    test('how to choose the boards and play, with the button names on the screen', () {
      expect(text, contains("On the screen, tap the centre (the bull) of Player 1's board, then Player 2's, then Lock boards."));
      expect(text, contains('tap Start again'));
      expect(text, contains('Tap Play. GO! shows when the countdown says go.'));
    });

    test('the winning rule: first to stick; bounce-out and false start lose', () {
      expect(text, contains('The first knife to stick wins. A bounce-out loses, and so does a knife before go (a false start).'));
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
      expect(text, contains('read the result from where you stand'));
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
      expect(paper, contains('A game is 9 rounds of 3 throws.'));
      expect([for (final s in instructionSections(const GameSession(), TargetModel.ikthof(), kind: InstructionTarget.paper)) s.heading],
          [for (final s in instructionSections(const GameSession(), TargetModel.ikthof())) s.heading]);
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
}
