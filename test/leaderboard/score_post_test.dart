import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/leaderboard/leaderboard_service.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/vision/throw_classifier.dart';
import 'package:thrower_app/scoring/game_type.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/ui/leaderboard_table_screen.dart';
import 'package:thrower_app/ui/post_score_panel.dart';
import 'package:thrower_app/ui/score_corrections.dart';

import '../game/game_notifier_test.dart' show calibration, event, stuckAt;
import '../history/memory_game_history.dart';
import '../ui/score_corrections_test.dart' show FakeHost;

/// Stands in for Game Center: records what was posted and shown.
class FakeLeaderboard implements LeaderboardService {
  var signedIn = true;
  var fails = false;

  /// While set, a post waits for it (a slow signal).
  Completer<void>? hold;
  final posted = <(Leaderboard, int)>[];
  final shown = <Leaderboard>[];

  @override
  Future<bool> signIn() async => signedIn;

  @override
  Future<void> submit(Leaderboard board, int score) async {
    await hold?.future;
    if (fails) throw StateError('no signal');
    posted.add((board, score));
  }

  @override
  Future<void> show(Leaderboard board) async {
    if (!signedIn) throw StateError('not signed in');
    shown.add(board);
  }

  /// Each week's table (empty if not set); [tableFails] for no signal.
  final tables = <LeaderboardWeek, LeaderboardTable>{};
  var tableFails = false;
  final tablesAsked = <(Leaderboard, LeaderboardWeek)>[];

  @override
  Future<LeaderboardTable> loadTable(Leaderboard board, LeaderboardWeek week, {int count = 25}) async {
    tablesAsked.add((board, week));
    if (!signedIn) throw const LeaderboardSignedOut();
    if (tableFails) throw StateError('no signal');
    return tables[week] ?? LeaderboardTable.empty;
  }
}

/// A Ranked game: [rounds] rounds of three 4s, then Finish game if [finish].
class RankedGame extends GameNotifier {
  RankedGame({this.rounds = 5, this.finish = false, this.type = GameType.ranked, this.then});

  final int rounds;
  final bool finish;
  final GameType type;

  /// A change made after the throws (a score set by hand).
  final Match Function(Match)? then;

  @override
  Match build() {
    var m = Match(PlayMode.solo, rules: const GameSession(maxRounds: 5), type: type);
    for (var r = 0; r < rounds; r++) {
      for (var i = 0; i < 3; i++) {
        m = m.stuck(4, const TargetPoint(0.1, 0));
      }
      m = m.boardVisited();
    }
    if (finish) m = m.finish();
    return then == null ? m : then!(m);
  }
}

void main() {
  late FakeLeaderboard board;

  setUp(() => board = FakeLeaderboard());

  ProviderContainer containerWith(GameNotifier Function() game, {bool canPost = true}) {
    final c = ProviderContainer(overrides: [
      gameProvider.overrideWith(game),
      if (canPost) leaderboardServiceProvider.overrideWithValue(board),
    ]);
    addTearDown(c.dispose);
    c.listen(scorePostProvider, (_, _) {});
    return c;
  }

  group('posting a score', () {
    test('a full ranked game posts its total to the 3 m leaderboard, once', () async {
      final c = containerWith(RankedGame.new);
      await c.read(scorePostProvider.notifier).post();
      await c.read(scorePostProvider.notifier).post();
      expect(board.posted, [(Leaderboard.ranked3m, 60)]);
      expect(c.read(scorePostProvider), ScorePost.posted);
    });

    // Posting-from-history story (2026-10-23): History says Posted.
    test('posted, the kept session is marked Posted', () async {
      final history = MemoryGameHistory();
      final c = ProviderContainer(overrides: [
        gameProvider.overrideWith(RankedGame.new),
        leaderboardServiceProvider.overrideWithValue(board),
        gameHistoryProvider.overrideWithValue(history),
      ]);
      addTearDown(c.dispose);
      c.listen(scorePostProvider, (_, _) {});
      await c.read(scorePostProvider.notifier).post();
      await Future<void>.delayed(Duration.zero);
      expect(history.games.single.posted, isTrue);
    });

    test('not posted (no signal): nothing kept as Posted', () async {
      final history = MemoryGameHistory();
      board.fails = true;
      final c = ProviderContainer(overrides: [
        gameProvider.overrideWith(RankedGame.new),
        leaderboardServiceProvider.overrideWithValue(board),
        gameHistoryProvider.overrideWithValue(history),
      ]);
      addTearDown(c.dispose);
      c.listen(scorePostProvider, (_, _) {});
      await c.read(scorePostProvider.notifier).post();
      expect(history.games.where((g) => g.posted), isEmpty);
    });

    test('not signed in to Game Center: nothing posted, it says so', () async {
      board.signedIn = false;
      final c = containerWith(RankedGame.new);
      await c.read(scorePostProvider.notifier).post();
      expect(board.posted, isEmpty);
      expect(c.read(scorePostProvider), ScorePost.signedOut);
    });

    test('no signal: failed, and trying again posts it', () async {
      board.fails = true;
      final c = containerWith(RankedGame.new);
      await c.read(scorePostProvider.notifier).post();
      expect(c.read(scorePostProvider), ScorePost.failed);
      board.fails = false;
      await c.read(scorePostProvider.notifier).post();
      expect((board.posted.length, c.read(scorePostProvider)), (1, ScorePost.posted));
    });

    final notPostable = <(String, GameNotifier Function())>[
      ('a game being played', () => RankedGame(rounds: 4)),
      ('a game finished early', () => RankedGame(rounds: 4, finish: true)),
      // Nigel, 2026-10-23: a normal 5 × 3 game can be posted, but not with a
      // score changed by hand.
      ('a Scoring game with a score changed by hand',
          () => RankedGame(type: GameType.scoring, then: (m) => m.setScore(0, 0, 0, 5))),
    ];
    for (final (name, game) in notPostable) {
      test('$name is not posted', () async {
        final c = containerWith(game);
        await c.read(scorePostProvider.notifier).post();
        expect(board.posted, isEmpty);
      });
    }

    // Traceability (2026-10-23): a score "changed" by hand to the value it
    // had changes no knife, but the session was still changed by hand: the
    // end panel stops offering Post score, so History mustn't offer it either.
    test('a normal 5 × 3 game: a score confirmed by hand at its own value after the end is kept as changed',
        () async {
      final history = MemoryGameHistory();
      final c = ProviderContainer(overrides: [
        gameProvider.overrideWith(() => RankedGame(type: GameType.scoring, rounds: 4)),
        leaderboardServiceProvider.overrideWithValue(board),
        gameHistoryProvider.overrideWithValue(history),
      ]);
      addTearDown(c.dispose);
      final game = c.read(gameProvider.notifier);
      final cal = calibration();
      for (var k = 0; k < 3; k++) {
        game.onEvent(stuckAt(500, 400, k), cal); // the last round, seen by the camera: kept
      }
      await Future<void>.delayed(Duration.zero);
      expect(history.games.single.changedByHand, isFalse);
      final score = c.read(gameProvider).players.single.rounds.first.throws.first.score;
      game.setScore(0, 0, 0, score); // picked its own value in the score picker
      await Future<void>.delayed(Duration.zero);
      expect(history.games.single.changedByHand, isTrue);
    });

    test('a new game can be posted again', () async {
      final c = containerWith(RankedGame.new);
      await c.read(scorePostProvider.notifier).post();
      c.read(gameProvider.notifier).newGame();
      expect(c.read(scorePostProvider), ScorePost.ready);
    });
  });

  group('the panel', () {
    Future<ProviderContainer> pump(WidgetTester tester, GameNotifier Function() game, {bool canPost = true}) async {
      final c = containerWith(game, canPost: canPost);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(backgroundColor: Colors.black, body: Center(child: PostScorePanel()))),
      ));
      return c;
    }

    testWidgets('Post score shows the total; posted, it says so and the button goes', (tester) async {
      await pump(tester, RankedGame.new);
      expect(find.text('Post score (60)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('postScore')));
      await tester.pumpAndSettle();
      expect(find.text('Posted to the leaderboard: 60.'), findsOneWidget);
      expect(find.byKey(const Key('postScore')), findsNothing);
    });

    // Nigel, 2026-10-23: a normal 5 × 3 game asks for 3 m before posting
    // (Ranked asked at its start).
    testWidgets('a normal 5 × 3 game: Post score waits for "I threw from 3 m"', (tester) async {
      await pump(tester, () => RankedGame(type: GameType.scoring));
      FilledButton button() => tester.widget<FilledButton>(find.byKey(const Key('postScore')));
      expect(button().onPressed, isNull);
      await tester.tap(find.byKey(const Key('postAt3m')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('postScore')));
      await tester.pumpAndSettle();
      expect(board.posted.single.$2, 60);
    });

    testWidgets('Ranked asks no 3 m tick (its setup did)', (tester) async {
      await pump(tester, RankedGame.new);
      expect(find.byKey(const Key('postAt3m')), findsNothing);
    });

    testWidgets('a failed post offers Try again', (tester) async {
      board.fails = true;
      await pump(tester, RankedGame.new);
      await tester.tap(find.byKey(const Key('postScore')));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining("Couldn't post"), findsOneWidget);
    });

    // Backlog #22: the week's tables, not Game Center's own screen.
    testWidgets("View leaderboard opens the 3 m leaderboard's tables", (tester) async {
      await pump(tester, RankedGame.new);
      await tester.tap(find.byKey(const Key('viewLeaderboard')));
      await tester.pumpAndSettle();
      expect(find.byType(LeaderboardTableScreen), findsOneWidget);
      expect(board.tablesAsked.first, (Leaderboard.ranked3m, LeaderboardWeek.thisWeek));
    });

    testWidgets('nothing for a game finished early', (tester) async {
      await pump(tester, () => RankedGame(rounds: 4, finish: true));
      expect(find.byKey(const Key('postScore')), findsNothing);
      expect(find.byKey(const Key('viewLeaderboard')), findsNothing);
    });

    testWidgets('nothing where scores can\'t be posted (Android, for now)', (tester) async {
      await pump(tester, RankedGame.new, canPost: false);
      expect(find.byKey(const Key('postScore')), findsNothing);
    });

    testWidgets('once posted, the scores can no longer be changed', (tester) async {
      final c = await pump(tester, RankedGame.new);
      await c.read(scorePostProvider.notifier).post();
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: Scaffold(body: Center(child: ScoreCorrections(host: FakeHost(), player: 0, board: 0)))),
      ));
      expect(find.byKey(const Key('rounds-0')), findsNothing);
    });
  });

  // Traceability fixes (2026-10-22).
  group('hardening', () {
    test('a ranked game played on a Live test recording is not posted', () async {
      final c = containerWith(RankedGame.new);
      c.read(recordingChoiceProvider.notifier).use(const Recording(name: 'Test', description: '', asset: ''));
      expect(c.read(scorePostProvider.notifier).canPost, isFalse);
      await c.read(scorePostProvider.notifier).post();
      expect(board.posted, isEmpty);
    });

    test('New game while a score is posting: the new game is not marked posted', () async {
      board.hold = Completer();
      final c = containerWith(RankedGame.new);
      final posting = c.read(scorePostProvider.notifier).post();
      expect(c.read(scorePostProvider), ScorePost.posting);
      c.read(gameProvider.notifier).newGame();
      board.hold!.complete();
      await posting;
      expect(c.read(scorePostProvider), ScorePost.ready);
    });

    test('a ranked game is one player\'s, whatever mode was last chosen', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(playModeProvider.notifier).choose(PlayMode.twoTargets);
      c.read(gameTypeProvider.notifier).choose(GameType.ranked);
      expect(c.read(gameProvider).mode, PlayMode.solo);
    });

    testWidgets('while posting, the scores can\'t be changed either', (tester) async {
      board.hold = Completer();
      final c = containerWith(RankedGame.new);
      unawaited(c.read(scorePostProvider.notifier).post());
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: Scaffold(body: Center(child: ScoreCorrections(host: FakeHost(), player: 0, board: 0)))),
      ));
      expect(find.byKey(const Key('rounds-0')), findsNothing);
      board.hold!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('View leaderboard, not signed in: the tables say to sign in', (tester) async {
      board.signedIn = false;
      final c = containerWith(RankedGame.new);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: Center(child: PostScorePanel()))),
      ));
      await tester.tap(find.byKey(const Key('viewLeaderboard')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tableSignedOut')), findsOneWidget);
    });
  });

  // Nigel, 2026-10-22: post at the end if you want to share it; once posted,
  // the score is final.
  group('a posted score is final', () {
    /// A live ranked game played by the camera: 15 bulls, the last round's
    /// knives not yet collected.
    Future<ProviderContainer> played() async {
      final c = ProviderContainer(overrides: [
        leaderboardServiceProvider.overrideWithValue(board),
        gameHistoryProvider.overrideWithValue(MemoryGameHistory()),
      ]);
      addTearDown(c.dispose);
      c.listen(scorePostProvider, (_, _) {});
      c.read(gameTypeProvider.notifier).choose(GameType.ranked);
      final game = c.read(gameProvider.notifier);
      final cal = calibration();
      for (var r = 0; r < 5; r++) {
        for (var i = 0; i < 3; i++) {
          game.onEvent(stuckAt(500, 400, r * 3 + i), cal);
        }
        if (r < 4) game.onEvent(event(ThrowOutcomeKind.boardVisit), cal);
      }
      return c;
    }

    test('a knife falling out after posting changes nothing', () async {
      final c = await played();
      expect(c.read(gameProvider).players.single.total, 75);
      await c.read(scorePostProvider.notifier).post();
      c.read(gameProvider.notifier).onEvent(event(ThrowOutcomeKind.fellOut, id: 14), calibration());
      expect(c.read(gameProvider).players.single.total, 75);
    });

    test('before posting, a knife falling out still scores 0 (and that is what can be posted)', () async {
      final c = await played();
      c.read(gameProvider.notifier).onEvent(event(ThrowOutcomeKind.fellOut, id: 14), calibration());
      expect(c.read(gameProvider).players.single.total, 70);
      await c.read(scorePostProvider.notifier).post();
      expect(board.posted.single.$2, 70);
    });
  });
}
