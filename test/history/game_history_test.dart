import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/history/game_history.dart';
import 'package:thrower_app/history/game_record.dart';
import 'package:thrower_app/scoring/match.dart';

/// A record finished on 16 Oct 2026 at 14:[minute], one player.
GameRecord game(int minute, {int score = 5}) => GameRecord(
      id: 'g$minute',
      finishedAt: DateTime(2026, 10, 16, 14, minute),
      mode: PlayMode.solo,
      rounds: 3,
      players: [
        [score, score, score]
      ],
    );

void main() {
  late Directory dir;
  late FileGameHistory history;

  File file() => File('${dir.path}${Platform.pathSeparator}${FileGameHistory.fileName}');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('game_history_test');
    history = FileGameHistory(() async => dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('empty before any game is kept (no file yet)', () async {
    expect(await history.load(), isEmpty);
    expect(file().existsSync(), isFalse);
  });

  test('keeps games, newest first', () async {
    await history.add(game(10));
    await history.add(game(30));
    await history.add(game(20));
    expect([for (final g in await history.load()) g.id], ['g30', 'g20', 'g10']);
  });

  test('a new history on the same folder (the app reopened) finds them', () async {
    await history.add(game(10, score: 4));
    final reopened = FileGameHistory(() async => dir);
    final games = await reopened.load();
    expect(games.single.totals, [12]);
  });

  test('the same game added twice is kept once', () async {
    await history.add(game(10));
    await history.add(game(10));
    expect(await history.load(), hasLength(1));
  });

  test('delete forgets one game; clear forgets them all', () async {
    await history.add(game(10));
    await history.add(game(20));
    await history.delete('g10');
    expect([for (final g in await history.load()) g.id], ['g20']);
    await history.clear();
    expect(await history.load(), isEmpty);
  });

  test('saves made at once all land, one after another', () async {
    await Future.wait([for (var m = 0; m < 10; m++) history.add(game(m))]);
    expect(await history.load(), hasLength(10));
  });

  test('no temporary file is left behind', () async {
    await history.add(game(10));
    expect(dir.listSync().map((e) => e.uri.pathSegments.last), [FileGameHistory.fileName]);
  });

  group('a damaged file', () {
    setUp(() => file().writeAsStringSync('{"version": 1, "games": [{"id": '));

    test('loading says it was set aside, keeping the old file under another name', () async {
      await expectLater(
        history.load(),
        throwsA(isA<GameHistoryException>().having((e) => e.setAside, 'setAside', isTrue)),
      );
      expect(file().existsSync(), isFalse);
      final aside = dir.listSync().whereType<File>().single;
      expect(aside.path, contains('.damaged-'));
      expect(aside.readAsStringSync(), startsWith('{"version": 1'));
    });

    test('a new game starts a fresh history', () async {
      await history.add(game(10));
      expect([for (final g in await history.load()) g.id], ['g10']);
    });
  });

  test('a history from a newer version of the app is set aside, not misread', () async {
    file().writeAsStringSync('{"version": 99, "games": []}');
    await expectLater(history.load(), throwsA(isA<GameHistoryException>()));
    expect(await history.load(), isEmpty);
  });

  test('a folder that can\'t be written says so', () async {
    // A file where the folder should be.
    final blocked = File('${dir.path}${Platform.pathSeparator}blocked')..writeAsStringSync('');
    final broken = FileGameHistory(() async => Directory(blocked.path));
    await expectLater(broken.add(game(10)), throwsA(isA<GameHistoryException>()));
  });
}
