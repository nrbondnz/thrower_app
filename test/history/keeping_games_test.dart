import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/history/game_history.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_type.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/vision/throw_classifier.dart';

import '../game/game_notifier_test.dart' show calibration, event, stuckAt;
import 'memory_game_history.dart';

/// Game-history story, Task 2: a game of Play is kept when it finishes,
/// once.
void main() {
  late ProviderContainer container;
  late MemoryGameHistory history;
  var now = DateTime(2026, 10, 16, 14, 32);
  final c = calibration();

  setUp(() {
    history = MemoryGameHistory();
    now = DateTime(2026, 10, 16, 14, 32);
    container = ProviderContainer(overrides: [
      gameHistoryProvider.overrideWithValue(history),
      clockProvider.overrideWithValue(() => now),
    ]);
    container.read(gameLengthProvider.notifier).choose(3);
  });
  tearDown(() => container.dispose());

  GameNotifier game() => container.read(gameProvider.notifier);

  // More-game-types story, Task 1.
  group('game types', () {
    test('Precision always plays 7 rounds, whatever length Scoring last used', () {
      container.read(gameTypeProvider.notifier).choose(GameType.precision);
      expect(container.read(gameProvider).maxRounds, 7);
    });

    test('Three targets plays the length chosen (3)', () {
      container.read(gameTypeProvider.notifier).choose(GameType.threeTargets);
      expect(container.read(gameProvider).type, GameType.threeTargets);
      expect(container.read(gameProvider).maxRounds, 3);
    });

    test('a hand-scored game is kept, with its type, when its last knife is added', () async {
      container.read(gameTypeProvider.notifier).choose(GameType.threeTargets);
      for (var i = 0; i < 9; i++) {
        game().addThrow(4);
      }
      await pumpEventQueue();
      expect(history.games.single.type, GameType.threeTargets);
      expect(history.games.single.totals, [36]);
    });

    test('New game keeps the type', () {
      container.read(gameTypeProvider.notifier).choose(GameType.precision);
      game().addThrow(5);
      game().newGame();
      expect(container.read(gameProvider).type, GameType.precision);
    });
  });

  /// [n] bull's-eyes (5 each) on [board], each a new knife, collecting
  /// after every 3rd.
  void throwBulls(int n, {int board = 0, int firstId = 0}) {
    for (var i = 0; i < n; i++) {
      game().onEvent(stuckAt(500, 400, firstId + i), c, board: board);
      if (i % 3 == 2) game().onEvent(event(ThrowOutcomeKind.boardVisit), c, board: board);
    }
  }

  test('nothing is kept while the game is on', () async {
    throwBulls(8);
    await pumpEventQueue();
    expect(history.games, isEmpty);
  });

  test('a finished game is kept, once, with when it finished', () async {
    throwBulls(9);
    await pumpEventQueue();
    final g = history.games.single;
    expect((g.mode, g.rounds, g.finishedAt, g.liveTest), (PlayMode.solo, 3, now, false));
    expect(g.players, [
      [15, 15, 15]
    ]);
  });

  test('throws after the end, and its board visit, don\'t keep it again', () async {
    throwBulls(9);
    await pumpEventQueue();
    game().onEvent(stuckAt(500, 400, 99), c);
    await pumpEventQueue();
    expect(history.saves, 1);
    expect(history.games, hasLength(1));
  });

  test('a last-round knife falling out after the end updates the kept game, not a new one', () async {
    // The last round isn't collected, so its knives are still in the board.
    throwBulls(8);
    game().onEvent(stuckAt(500, 400, 8), c);
    await pumpEventQueue();
    now = now.add(const Duration(minutes: 1));
    game().onEvent(event(ThrowOutcomeKind.fellOut, id: 8), c);
    await pumpEventQueue();
    final g = history.games.single;
    expect(g.players.single.last, 10, reason: 'the fallen knife scores 0 now');
    expect(g.finishedAt, DateTime(2026, 10, 16, 14, 32), reason: 'kept under the time it finished');
  });

  test('New game, then a second finished game: two kept', () async {
    throwBulls(9);
    game().newGame();
    now = now.add(const Duration(minutes: 5));
    throwBulls(9, firstId: 100);
    await pumpEventQueue();
    expect(history.games, hasLength(2));
  });

  test('a game reset half-way is not kept', () async {
    throwBulls(5);
    game().newGame();
    await pumpEventQueue();
    expect(history.games, isEmpty);
  });

  test('a two-player game is kept when both have finished, with the winner', () async {
    container.read(playModeProvider.notifier).choose(PlayMode.twoTargets);
    throwBulls(9, board: 0);
    await pumpEventQueue();
    expect(history.games, isEmpty, reason: 'Player 2 is still playing');
    // Player 2: 0 · 5 · 5, then two rounds of bull's-eyes: 40.
    game()
      ..onEvent(event(ThrowOutcomeKind.bounceOut), c, board: 1)
      ..onEvent(stuckAt(500, 400, 50), c, board: 1)
      ..onEvent(stuckAt(500, 400, 51), c, board: 1)
      ..onEvent(event(ThrowOutcomeKind.boardVisit), c, board: 1);
    throwBulls(6, board: 1, firstId: 60);
    await pumpEventQueue();
    final g = history.games.single;
    expect((g.mode, g.winner), (PlayMode.twoTargets, 0));
    expect(g.totals, [45, 40]);
  });

  test('a Live test game is kept with its recording\'s name', () async {
    container.read(recordingChoiceProvider.notifier).use(liveTestRecordings.first);
    container.read(gameLengthProvider.notifier).choose(3);
    throwBulls(9);
    await pumpEventQueue();
    expect(history.games.single.recording, 'Target 1');
  });

  test("if it can't be saved, play goes on and the reason is kept for Play to show", () async {
    history.failWith = const GameHistoryException("couldn't save the history: disk full");
    throwBulls(9);
    await pumpEventQueue();
    expect(container.read(gameProvider).isOver, isTrue);
    expect(container.read(historySaveErrorProvider), contains('disk full'));
    // The next save that works clears it.
    history.failWith = null;
    game().newGame();
    throwBulls(9, firstId: 100);
    await pumpEventQueue();
    expect(container.read(historySaveErrorProvider), isNull);
  });

  // Finish game (Task 5).
  test('Finish game keeps the game, once, with the round in progress', () async {
    throwBulls(4);
    game().finishGame();
    game().finishGame();
    await pumpEventQueue();
    expect(history.saves, 1);
    expect(history.games.single.players, [
      [15, 5]
    ]);
    expect(container.read(gameProvider).isOver, isTrue);
  });

  test('Finish game with no throws does nothing', () async {
    game().finishGame();
    await pumpEventQueue();
    expect(container.read(gameProvider).isOver, isFalse);
    expect(history.games, isEmpty);
  });

  // Score corrections story, Task 1.
  test('a miss added by hand can finish the game, and it is kept', () async {
    throwBulls(8);
    game().addThrow(0);
    await pumpEventQueue();
    expect(history.games.single.players.single, [15, 15, 10]);
  });

  test('a correction after the end re-saves the same game, under the same time', () async {
    throwBulls(9);
    await pumpEventQueue();
    now = now.add(const Duration(minutes: 2));
    game().setScore(0, 0, 0, 1);
    await pumpEventQueue();
    expect((history.saves, history.games.length), (2, 1));
    expect(history.games.single.players.single.first, 11);
    expect(history.games.single.finishedAt, DateTime(2026, 10, 16, 14, 32));
  });

  test('a correction during the game keeps nothing yet', () async {
    throwBulls(2);
    game().setScore(0, 0, 0, 1);
    await pumpEventQueue();
    expect(history.games, isEmpty);
  });

  test('no throw is added by hand once the game is over', () async {
    throwBulls(9);
    game().addThrow(5);
    expect(container.read(gameProvider).players.single.total, 45);
  });

  // Named-players story (2026-10-19).
  group('names', () {
    test('a finished game is kept with its players\' names', () async {
      container.read(playModeProvider.notifier).choose(PlayMode.twoTargets);
      container.read(playerNamesProvider.notifier).set(['Jo', 'Sam']);
      throwBulls(9, board: 0);
      throwBulls(9, board: 1, firstId: 100);
      await pumpEventQueue();
      expect(history.games.single.names, ['Jo', 'Sam']);
    });

    test('renaming during a game keeps the scores', () {
      throwBulls(2);
      container.read(playerNamesProvider.notifier).set(['Jo']);
      final m = container.read(gameProvider);
      expect((m.nameOf(0), m.players.single.total), ('Jo', 10));
    });

    test('New game keeps the names', () {
      container.read(playerNamesProvider.notifier).set(['Jo']);
      throwBulls(2);
      game().newGame();
      final m = container.read(gameProvider);
      expect((m.nameOf(0), m.isEmpty), ('Jo', true));
    });
  });
}