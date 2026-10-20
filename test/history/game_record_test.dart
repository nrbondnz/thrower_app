import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/history/game_record.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/match.dart';
import 'package:thrower_app/scoring/target_model.dart';

const p = TargetPoint(0.1, 0);

/// A finished 1-round two-player game on one target: Player 1 4+3+0,
/// Player 2 5+5+2.
Match finishedShared() => Match(PlayMode.sharedTarget, rules: const GameSession(maxRounds: 1))
    .stuck(4, p)
    .stuck(3, p)
    .bounceOut()
    .boardVisited()
    .stuck(5, p)
    .stuck(5, p)
    .stuck(2, p);

void main() {
  final at = DateTime(2026, 10, 16, 14, 32);

  test('from a finished match: when, how, each player\'s rounds, totals and the winner', () {
    final r = GameRecord.fromMatch(finishedShared(), at: at);
    expect(r.finishedAt, at);
    expect(r.mode, PlayMode.sharedTarget);
    expect(r.rounds, 1);
    expect(r.players, [
      [7],
      [12]
    ]);
    expect(r.totals, [7, 12]);
    expect((r.winner, r.draw, r.liveTest), (1, false, false));
  });

  test('a Live test game names its recording', () {
    final r = GameRecord.fromMatch(finishedShared(), at: at, recording: 'Target 1');
    expect((r.liveTest, r.recording), (true, 'Target 1'));
  });

  test('one player has no winner; equal totals are a draw', () {
    final solo = GameRecord(id: '1', finishedAt: at, mode: PlayMode.solo, rounds: 3, players: const [
      [5, 6, 7]
    ]);
    expect((solo.winner, solo.draw), (null, false));
    final drawn = GameRecord(id: '2', finishedAt: at, mode: PlayMode.twoTargets, rounds: 1, players: const [
      [9],
      [9]
    ]);
    expect((drawn.winner, drawn.draw), (null, true));
  });

  test('survives JSON both ways (through text, as in the file)', () {
    final r = GameRecord.fromMatch(finishedShared(), at: at, recording: 'Target 2');
    final back = GameRecord.fromJson(jsonDecode(jsonEncode(r.toJson())));
    expect(back.id, r.id);
    expect(back.finishedAt, at);
    expect((back.mode, back.rounds, back.recording), (PlayMode.sharedTarget, 1, 'Target 2'));
    expect(back.players, r.players);
  });

  test('a camera game has no recording in its JSON', () {
    expect(GameRecord.fromMatch(finishedShared(), at: at).toJson().containsKey('recording'), isFalse);
  });

  group('JSON it can\'t read is a FormatException', () {
    Map<String, Object?> good() => GameRecord.fromMatch(finishedShared(), at: at).toJson();
    for (final (name, change) in <(String, void Function(Map<String, Object?>))>[
      ('an unknown mode', (j) => j['mode'] = 'fourTargets'),
      ('a missing id', (j) => j.remove('id')),
      ('a round total that is not a number', (j) => j['players'] = [
            ['7'],
            [12]
          ]),
      ('the wrong number of players for the mode', (j) => j['players'] = [
            [7]
          ]),
      ('a date that is not a date', (j) => j['finishedAt'] = 'yesterday'),
    ]) {
      test(name, () {
        final j = good();
        change(j);
        expect(() => GameRecord.fromJson(j), throwsFormatException);
      });
    }

    test('not an object at all', () => expect(() => GameRecord.fromJson([1, 2]), throwsFormatException));
  });

  // Finish game (2026-10-17): the record judges on equal rounds too.
  test('finished early: shows fewer rounds, and the winner is on equal rounds', () {
    var m = Match(PlayMode.sharedTarget);
    for (final s in [3, 3, 3, 1, 1, 1, 5, 5, 5]) {
      m = m.stuck(s, p);
      if (m.turnComplete) m = m.boardVisited();
    }
    final r = GameRecord.fromMatch(m.finish(), at: at);
    expect((r.finishedEarly, r.countedRounds), (true, 1));
    expect([r.countedTotals, r.totals], [
      [9, 3],
      [24, 3],
    ]);
    expect(r.winner, 0);
    expect(GameRecord.fromJson(jsonDecode(jsonEncode(r.toJson()))).winner, 0, reason: 'no format change');
  });

  // Named-players story (2026-10-19): version 2 keeps each player's name.
  group('names', () {
    test('a game keeps the names it was played with', () {
      final r = GameRecord.fromMatch(finishedShared().withNames(['Jo', null]), at: at);
      expect([r.nameOf(0), r.nameOf(1)], ['Jo', 'Player 2']);
    });

    test('names survive saving and reading back', () {
      final r = GameRecord.fromMatch(finishedShared().withNames(['Jo', 'Sam']), at: at);
      expect(GameRecord.fromJson(jsonDecode(jsonEncode(r.toJson()))).names, ['Jo', 'Sam']);
    });

    test('a game with no names writes none', () {
      expect(GameRecord.fromMatch(finishedShared(), at: at).toJson().containsKey('names'), isFalse);
    });

    test('a game kept before names (version 1) reads as Player 1 and Player 2', () {
      final old = GameRecord.fromMatch(finishedShared(), at: at).toJson()..remove('names');
      final r = GameRecord.fromJson(old);
      expect([r.nameOf(0), r.nameOf(1)], ['Player 1', 'Player 2']);
    });

    test('names that aren\'t one per player are not misread', () {
      final json = GameRecord.fromMatch(finishedShared(), at: at).toJson()..['names'] = ['Jo'];
      expect(() => GameRecord.fromJson(json), throwsFormatException);
      final wrongType = GameRecord.fromMatch(finishedShared(), at: at).toJson()..['names'] = [1, 2];
      expect(() => GameRecord.fromJson(wrongType), throwsFormatException);
    });

    test('the format is version 3 (more-game-types story: the game type)', () {
      expect(GameRecord.version, 3);
    });
  });
}
