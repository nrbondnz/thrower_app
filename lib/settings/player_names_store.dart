import 'dart:convert';
import 'dart:io';

/// The player names last used, kept on the phone so Play's setup screen (and
/// Quick draw) can fill them in next time (named-players story, Nigel
/// 2026-10-19). An interface, like `GameHistory`; tests use a temporary
/// folder or a fake.
abstract interface class PlayerNamesStore {
  /// The names kept, Player 1 first (null for none); empty if none are kept
  /// or they can't be read. Never throws: the names are a convenience.
  Future<List<String?>> load();

  /// Keeps [names]. Throws [FileSystemException] if they can't be saved.
  Future<void> save(List<String?> names);
}

/// [PlayerNamesStore] in one small JSON file, [fileName], in the folder
/// [directory] gives (the app's own support folder, beside the history).
/// Writes go to a temporary file that then replaces the old one, one at a
/// time. A file that can't be read is ignored (the names start blank) and
/// replaced by the next save.
class FilePlayerNamesStore implements PlayerNamesStore {
  FilePlayerNamesStore(this.directory);

  final Future<Directory> Function() directory;
  static const fileName = 'player_names.json';

  /// The last write, so the next one waits for it.
  Future<void> _writing = Future.value();

  Future<File> get _file async {
    final dir = await directory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<List<String?>> load() async {
    await _writing;
    try {
      final file = await _file;
      if (!await file.exists()) return const [];
      final json = jsonDecode(await file.readAsString());
      final names = json is Map<String, Object?> ? json['names'] : null;
      if (names is! List<Object?>) return const [];
      return [for (final n in names) n is String ? n : null];
    } catch (_) {
      // No folder, unreadable or not JSON: start blank.
      return const [];
    }
  }

  @override
  Future<void> save(List<String?> names) {
    final next = _writing.then((_) async {
      final file = await _file;
      final temp = File('${file.path}.tmp');
      await file.parent.create(recursive: true);
      await temp.writeAsString(jsonEncode({'version': 1, 'names': names}), flush: true);
      await temp.rename(file.path);
    });
    _writing = next.then((_) {}, onError: (_) {});
    return next;
  }
}
