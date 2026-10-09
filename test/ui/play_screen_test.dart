import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/ui/play_screen.dart';

import 'system_bars_test.dart' show LockedCalibration, pumpWithNavBar;

const p = TargetPoint(0.1, 0.1);

/// A game that starts with [throws] scored throws of 4.
class GameWith extends GameNotifier {
  GameWith(this.throws);

  final int throws;

  @override
  GameSession build() {
    var g = const GameSession();
    for (var i = 0; i < throws; i++) {
      g = g.stuck(4, p);
    }
    return g;
  }
}

Future<void> pumpPlay(WidgetTester tester, int throws) => pumpWithNavBar(tester, const PlayScreen(), overrides: [
      calibrationProvider.overrideWith(LockedCalibration.new),
      gameProvider.overrideWith(() => GameWith(throws)),
    ]);

/// The camera's loading spinner never stops in tests, so pumpAndSettle would
/// time out: pump long enough for dialog animations instead.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

String gameText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('gameText'))).data!;

void main() {
  testWidgets('Reset game is disabled before the first throw', (tester) async {
    await pumpPlay(tester, 0);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Reset game')).onPressed, isNull);
  });

  testWidgets('Reset game asks first; Cancel keeps the scores', (tester) async {
    await pumpPlay(tester, 2);
    await tester.tap(find.text('Reset game'));
    await settle(tester);
    expect(find.text('Reset this game?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(gameText(tester), contains('Game total: 8'));
  });

  testWidgets('confirming Reset clears the game', (tester) async {
    await pumpPlay(tester, 2);
    await tester.tap(find.text('Reset game'));
    await settle(tester);
    await tester.tap(find.text('Reset'));
    await settle(tester);
    expect(gameText(tester), 'Game total: 0');
  });

  testWidgets('no New game button while the game is on', (tester) async {
    await pumpPlay(tester, 26);
    expect(find.widgetWithText(FilledButton, 'New game'), findsNothing);
  });

  testWidgets('game over shows New game, which starts again without asking', (tester) async {
    await pumpPlay(tester, 27);
    expect(gameText(tester), startsWith('Game over! Final total: 108'));
    await tester.tap(find.widgetWithText(FilledButton, 'New game'));
    await settle(tester);
    expect(find.text('Reset this game?'), findsNothing);
    expect(gameText(tester), 'Game total: 0');
  });
}
