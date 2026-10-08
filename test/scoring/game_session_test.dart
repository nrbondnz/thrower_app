import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/scoring/game_session.dart';
import 'package:thrower_app/scoring/target_model.dart';

const p = TargetPoint(0.1, 0.1);

void main() {
  test('a new game has no rounds and scores 0', () {
    const g = GameSession();
    expect(g.rounds, isEmpty);
    expect(g.total, 0);
    expect(g.roundComplete, isFalse);
  });

  test('three throws make a complete round with their total', () {
    final g = const GameSession().stuck(4, p).stuck(3, p).bounceOut();
    expect(g.rounds, hasLength(1));
    expect([for (final t in g.rounds.single.throws) t.score], [4, 3, 0]);
    expect(g.rounds.single.total, 7);
    expect(g.roundComplete, isTrue);
  });

  test('throwing on after a full round starts the next round', () {
    final g = const GameSession().stuck(4, p).stuck(3, p).stuck(5, p).stuck(2, p);
    expect(g.rounds, hasLength(2));
    expect(g.rounds.last.total, 2);
    expect(g.total, 14);
  });

  test('a board visit closes a round early; the next throw starts a new round', () {
    final g = const GameSession().stuck(4, p).boardVisited().stuck(5, p);
    expect(g.rounds, hasLength(2));
    expect(g.rounds.first.closed, isTrue);
    expect(g.rounds.first.total, 4);
    expect(g.rounds.last.total, 5);
  });

  test('a board visit with no throws in the round changes nothing', () {
    const g = GameSession();
    expect(identical(g.boardVisited(), g), isTrue);
    final full = const GameSession().stuck(1, p).stuck(1, p).stuck(1, p).boardVisited();
    expect(identical(full.boardVisited(), full), isTrue);
  });

  test('a knife that falls out scores 0 and keeps its place', () {
    final g = const GameSession().stuck(4, p).stuck(3, p).fellOut(0, 0);
    expect(g.rounds.single.throws.first.result, ThrowResult.fellOut);
    expect(g.rounds.single.throws.first.score, 0);
    expect(g.rounds.single.total, 3);
  });

  test('a stuck knife whose entry was not found counts as a throw, unscored', () {
    final g = const GameSession().stuck(4, null);
    expect(g.rounds.single.throws.single.unscored, isTrue);
    expect(g.total, 0);
  });

  test('rounds of a different length', () {
    final g = const GameSession(throwsPerRound: 2).stuck(1, p).stuck(1, p).stuck(1, p);
    expect(g.rounds, hasLength(2));
  });
}
