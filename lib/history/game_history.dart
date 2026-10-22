import 'dart:convert';
import 'dart:io';

import '../scoring/game_type.dart';
import 'game_record.dart';

/// The finished games kept on the phone (game-history story). An interface,
/// so a backend can keep them instead once there are accounts (backlog #4);
/// tests use a temporary folder or a fake.
abstract interface class GameHistory {
  /// Every kept game, newest first. Throws [GameHistoryException] if the
  /// history can't be read.
  Future<List<GameRecord>> load();

  /// Keeps [record]. Throws [GameHistoryException] if it can't be saved.
  Future<void> add(GameRecord record);

  /// Forgets the game with [id] (nothing if there's none).
  Future<void> delete(String id);

  /// Forgets every game.
  Future<void> clear();
}

class GameHistoryException implements Exception {
  const GameHistoryException(this.message, {this.setAside = false});

  final String message;

  /// The file was damaged and has been renamed, not deleted: new games are
  /// kept from now on.
  final bool setAside;

  @override
  String toString() => 'GameHistoryException: $message';
}

/// [GameHistory] in one JSON file, [fileName], in the folder [directory]
/// gives (the app's own support folder: private to the app, not shown in
/// the Files app). Writes go to a temporary file that then replaces the old
/// one, one at a time, so a write cut short can't leave half a file. A file
/// that can't be read as a history is renamed (`….damaged-<time>`) rather
/// than deleted, and the history starts afresh.
class FileGameHistory implements GameHistory {
  FileGameHistory(this.directory);

  final Future<Directory> Function() directory;
  static const fileName = 'game_history.json';

  /// The last write, so the next one waits for it.
  Future<void> _writing = Future.value();

  Future<File> get _file async {
    final Directory dir;
    try {
      dir = await directory();
    } catch (e) {
      // Whatever the platform throws (no plugin, no folder): Play goes on.
      throw GameHistoryException("couldn't find the app's folder: $e");
    }
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<List<GameRecord>> load() async {
    await _writing;
    return _read();
  }

  @override
  Future<void> add(GameRecord record) => _update((games) => [record, ...games.where((g) => g.id != record.id)]);

  @override
  Future<void> delete(String id) => _update((games) => [...games.where((g) => g.id != id)]);

  @override
  Future<void> clear() => _update((_) => const []);

  Future<void> _update(List<GameRecord> Function(List<GameRecord>) change) {
    final next = _writing.then((_) async {
      List<GameRecord> games;
      try {
        games = await _read();
      } on GameHistoryException catch (e) {
        if (!e.setAside) rethrow;
        games = const [];
      }
      await _write(change(games));
    });
    // The next write waits for this one, whether it worked or not.
    _writing = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<List<GameRecord>> _read() async {
    final file = await _file;
    final String text;
    try {
      if (!await file.exists()) return const [];
      text = await file.readAsString();
    } on FileSystemException catch (e) {
      throw GameHistoryException("couldn't read the history: ${e.message}");
    }
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, Object?> || json['games'] is! List<Object?>) {
        throw const FormatException('not a game history');
      }
      final version = json['version'];
      if (version is! int || version > GameRecord.version) throw FormatException('history version $version');
      final games = [for (final g in json['games'] as List<Object?>) GameRecord.fromJson(g)];
      return games..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));
    } on FormatException catch (e) {
      final aside = '${file.path}.damaged-${DateTime.now().millisecondsSinceEpoch}';
      try {
        await file.rename(aside);
      } on FileSystemException {
        throw GameHistoryException('the history is damaged (${e.message}) and could not be set aside');
      }
      throw GameHistoryException('the history was damaged (${e.message}); it was set aside', setAside: true);
    }
  }

  /// The oldest format that holds [games]: version 2 while every game is
  /// Scoring (its format didn't change), so an older build of the app can
  /// still read the file; [GameRecord.version] once a Precision or Three
  /// targets game is in it.
  static int _versionFor(List<GameRecord> games) =>
      games.any((g) => g.type != GameType.scoring) ? GameRecord.version : 2;

  Future<void> _write(List<GameRecord> games) async {
    final file = await _file;
    final temp = File('${file.path}.tmp');
    try {
      await file.parent.create(recursive: true);
      await temp.writeAsString(
        jsonEncode({
          'version': _versionFor(games),
          'games': [for (final g in games) g.toJson()],
        }),
        flush: true,
      );
      await temp.rename(file.path);
    } on FileSystemException catch (e) {
      throw GameHistoryException("couldn't save the history: ${e.message}");
    }
  }
}
