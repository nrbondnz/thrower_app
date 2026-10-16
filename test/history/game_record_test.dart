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
}
