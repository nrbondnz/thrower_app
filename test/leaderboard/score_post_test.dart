import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/leaderboard/leaderboard_service.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/game_type.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/scoring/target_model.dart';
import 'package:thrower_app/ui/post_score_panel.dart';
import 'package:thrower_app/ui/score_corrections.dart';

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
}

/// A Ranked game: [rounds] rounds of three 4s, then Finish game if [finish].
class RankedGame extends GameNotifier {
  RankedGame({this.rounds = 5, this.finish = false, this.type = GameType.ranked});

  final int rounds;
  final bool finish;
  final GameType type;

  @override
  Match build() {
    var m = Match(PlayMode.solo, rules: const GameSession(maxRounds: 5), type: type);
    for (var r = 0; r < rounds; r++) {
      for (var i = 0; i < 3; i++) {
        m = m.stuck(4, const TargetPoint(0.1, 0));
      }
      m = m.boardVisited();
    }
    return finish ? m.finish() : m;
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
      ('a Scoring game', () => RankedGame(type: GameType.scoring)),
    ];
    for (final (name, game) in notPostable) {
      test('$name is not posted', () async {
        final c = containerWith(game);
        await c.read(scorePostProvider.notifier).post();
        expect(board.posted, isEmpty);
      });
    }

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

    testWidgets('a failed post offers Try again', (tester) async {
      board.fails = true;
      await pump(tester, RankedGame.new);
      await tester.tap(find.byKey(const Key('postScore')));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining("Couldn't post"), findsOneWidget);
    });

    testWidgets('View leaderboard opens the 3 m leaderboard', (tester) async {
      await pump(tester, RankedGame.new);
      await tester.tap(find.byKey(const Key('viewLeaderboard')));
      await tester.pump();
      expect(board.shown, [Leaderboard.ranked3m]);
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

    testWidgets('View leaderboard says so when it can\'t open (not signed in)', (tester) async {
      board.signedIn = false;
      final c = containerWith(RankedGame.new);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: Center(child: PostScorePanel()))),
      ));
      await tester.tap(find.byKey(const Key('viewLeaderboard')));
      await tester.pump();
      expect(find.byKey(const Key('viewLeaderboardFailed')), findsOneWidget);
      expect(board.shown, isEmpty);
    });
  });
}
