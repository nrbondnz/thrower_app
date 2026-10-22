import 'dart:convert';
import 'dart:io';

/// Setup → Appearance (app-design story, Nigel 2026-10-23: "follow phone +
/// override").
enum Appearance {
  /// Light or dark as the phone is set.
  phone('Phone'),
  light('Light'),
  dark('Dark');

  const Appearance(this.label);

  /// The name shown in Setup.
  final String label;
}

/// The Appearance setting, kept on the phone. An interface, like
/// `PlayerNamesStore`; tests use a fake.
abstract interface class AppearanceStore {
  /// The setting kept, or [Appearance.phone] if none is kept or it can't be
  /// read. Never throws: it's a convenience.
  Future<Appearance> load();

  /// Keeps [appearance]. Throws [FileSystemException] if it can't be saved.
  Future<void> save(Appearance appearance);
}

/// [AppearanceStore] in one small JSON file, [fileName], in the folder
/// [directory] gives (the app's own support folder, beside the history).
class FileAppearanceStore implements AppearanceStore {
  FileAppearanceStore(this.directory);

  final Future<Directory> Function() directory;
  static const fileName = 'appearance.json';

  Future<File> get _file async {
    final dir = await directory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<Appearance> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return Appearance.phone;
      final json = jsonDecode(await file.readAsString());
      final name = json is Map<String, Object?> ? json['appearance'] : null;
      return Appearance.values.where((a) => a.name == name).firstOrNull ?? Appearance.phone;
    } catch (_) {
      // No folder (as in tests), or a file that can't be read: the default.
      return Appearance.phone;
    }
  }

  @override
  Future<void> save(Appearance appearance) async {
    final file = await _file;
    await file.writeAsString(jsonEncode({'appearance': appearance.name}), flush: true);
  }
}
