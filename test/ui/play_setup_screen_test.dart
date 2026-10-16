import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/target_camera.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/ui/play_screen.dart';
import 'package:thrower_app/ui/play_setup_screen.dart';

import '../scoring/match_test.dart' show p;

void main() {
  late ProviderContainer container;

  Future<void> pumpSetup(WidgetTester tester) async {
    container = ProviderContainer(overrides: [
      // Play's camera never starts in a test.
      cameraProvider.overrideWith((ref) => Completer<TargetCamera>().future),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlaySetupScreen()),
    ));
  }

  Future<void> tapSegment(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('playStart')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // The page transition.
  }

  bool startEnabled(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const Key('playStart'))).onPressed != null;

  String description(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('playModeDescription'))).data!;

  testWidgets('starts on 1 player, with no target choice', (tester) async {
    await pumpSetup(tester);
    expect(find.text('How many players?'), findsOneWidget);
    expect(find.text('How many targets?'), findsNothing);
    expect(description(tester), modeDescription(PlayMode.solo));
  });

  testWidgets('2 players asks how many targets, 1 first', (tester) async {
    await pumpSetup(tester);
    await tapSegment(tester, '2 players');
    expect(find.text('How many targets?'), findsOneWidget);
    expect(description(tester), modeDescription(PlayMode.sharedTarget));
    await tapSegment(tester, '2 targets');
    expect(description(tester), modeDescription(PlayMode.twoTargets));
  });

  testWidgets('two targets says each thrower needs their own lane and to collect together', (tester) async {
    expect(modeDescription(PlayMode.twoTargets), contains('own lane'));
    expect(modeDescription(PlayMode.twoTargets), contains('collect your knives together'));
  });

  testWidgets('Start with 1 player opens Play in single-player mode', (tester) async {
    await pumpSetup(tester);
    await start(tester);
    expect(find.byType(PlayScreen), findsOneWidget);
    expect(container.read(playModeProvider), PlayMode.solo);
  });

  testWidgets('Start with 2 players on 1 target opens Play taking turns', (tester) async {
    await pumpSetup(tester);
    await tapSegment(tester, '2 players');
    expect(find.text('Coming soon.'), findsNothing);
    await start(tester);
    expect(find.byType(PlayScreen), findsOneWidget);
    expect(container.read(gameProvider).mode, PlayMode.sharedTarget);
  });

  // Players-and-targets story: two players on two targets comes in Task 3.
  testWidgets('two targets is not playable yet', (tester) async {
    await pumpSetup(tester);
    await tapSegment(tester, '2 players');
    await tapSegment(tester, '2 targets');
    expect(startEnabled(tester), isFalse);
    expect(find.text('Coming soon.'), findsOneWidget);
  });

  testWidgets('opens on the last choice', (tester) async {
    await pumpSetup(tester);
    container.read(playModeProvider.notifier).choose(PlayMode.twoTargets);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlaySetupScreen(key: Key('again'))),
    ));
    expect(description(tester), modeDescription(PlayMode.twoTargets));
  });

  testWidgets('Start with the same choice keeps the game in progress', (tester) async {
    await pumpSetup(tester);
    container.read(gameProvider.notifier).state = Match(PlayMode.solo).stuck(4, p);
    await start(tester);
    expect(container.read(gameProvider).players.single.total, 4);
  });
}
