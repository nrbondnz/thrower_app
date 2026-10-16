import 'package:thrower_app/history/game_history.dart';
import 'package:thrower_app/history/game_record.dart';

/// A [GameHistory] in memory, for tests: [saves] counts every `add`, and
/// [failWith] makes every call fail.
class MemoryGameHistory implements GameHistory {
  MemoryGameHistory([List<GameRecord> games = const []]) : games = [...games];

  final List<GameRecord> games;
  var saves = 0;
  GameHistoryException? failWith;

  void _check() {
    if (failWith case final e?) throw e;
  }

  @override
  Future<List<GameRecord>> load() async {
    _check();
    return [...games]..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
  }

  @override
  Future<void> add(GameRecord record) async {
    _check();
    saves++;
    games
      ..removeWhere((g) => g.id == record.id)
      ..add(record);
  }

  @override
  Future<void> delete(String id) async {
    _check();
    games.removeWhere((g) => g.id == id);
  }

  @override
  Future<void> clear() async {
    _check();
    games.clear();
  }
}
