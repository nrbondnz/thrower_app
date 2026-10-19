import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/settings/player_names_store.dart';

/// A [PlayerNamesStore] in memory, recording what's saved.
class MemoryPlayerNamesStore implements PlayerNamesStore {
  MemoryPlayerNamesStore([this.kept = const []]);

  List<String?> kept;
  var saves = 0;

  @override
  Future<List<String?>> load() async => kept;

  @override
  Future<void> save(List<String?> names) async {
    kept = names;
    saves++;
  }
}

/// Named-players story (Nigel, 2026-10-19): the last names used are kept on
/// the phone and filled in next time.
void main() {
  group('FilePlayerNamesStore', () {
    late Directory dir;
    late FilePlayerNamesStore store;

    File file() => File('${dir.path}${Platform.pathSeparator}${FilePlayerNamesStore.fileName}');

    setUp(() {
      dir = Directory.systemTemp.createTempSync('player_names_test');
      store = FilePlayerNamesStore(() async => dir);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('nothing kept yet: no names', () async {
      expect(await store.load(), isEmpty);
    });

    test('names kept are there next time (the app reopened)', () async {
      await store.save(['Mark', null]);
      expect(await FilePlayerNamesStore(() async => dir).load(), ['Mark', null]);
    });

    test('a damaged file: no names, and the next save replaces it', () async {
      file().writeAsStringSync('{"names": [');
      expect(await store.load(), isEmpty);
      await store.save(['Sam']);
      expect(await store.load(), ['Sam']);
    });

    test('no folder: no names, no crash', () async {
      expect(await FilePlayerNamesStore(() async => throw const FileSystemException('none')).load(), isEmpty);
    });

    test('no temporary file is left behind', () async {
      await store.save(['Jo', 'Sam']);
      expect(dir.listSync().map((f) => f.uri.pathSegments.last), [FilePlayerNamesStore.fileName]);
    });
  });

  group('playerNamesProvider', () {
    late MemoryPlayerNamesStore store;
    late ProviderContainer container;

    setUp(() {
      store = MemoryPlayerNamesStore(['Mark', 'Sam']);
      container = ProviderContainer(overrides: [playerNamesStoreProvider.overrideWithValue(store)]);
    });
    tearDown(() => container.dispose());

    test('starts blank, then takes the names kept on the phone', () async {
      expect(container.read(playerNamesProvider), [null, null]);
      await pumpEventQueue();
      expect(container.read(playerNamesProvider), ['Mark', 'Sam']);
    });

    test('names set are cleaned and kept', () async {
      container.read(playerNamesProvider.notifier).set([' Jo ', '']);
      expect(container.read(playerNamesProvider), ['Jo', null]);
      await pumpEventQueue();
      expect(store.kept, ['Jo', null]);
      expect(store.saves, 1);
    });

    test('names set before the kept ones load are not overwritten by them', () async {
      container.read(playerNamesProvider);
      container.read(playerNamesProvider.notifier).set(['Jo']);
      await pumpEventQueue();
      expect(container.read(playerNamesProvider), ['Jo', null]);
    });

    test('a store that can\'t save doesn\'t stop the names changing', () async {
      final failing = ProviderContainer(overrides: [playerNamesStoreProvider.overrideWithValue(_FailingStore())]);
      addTearDown(failing.dispose);
      failing.read(playerNamesProvider.notifier).set(['Jo']);
      await pumpEventQueue();
      expect(failing.read(playerNamesProvider), ['Jo', null]);
    });
  });
}

class _FailingStore implements PlayerNamesStore {
  @override
  Future<List<String?>> load() async => const [];

  @override
  Future<void> save(List<String?> names) async => throw const FileSystemException('full');
}
