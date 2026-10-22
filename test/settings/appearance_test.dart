import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/settings/appearance_store.dart';
import 'package:thrower_app/ui/theme/app_theme.dart';

/// An [AppearanceStore] in memory.
class MemoryAppearanceStore implements AppearanceStore {
  MemoryAppearanceStore([this.kept = Appearance.phone]);

  Appearance kept;
  var saves = 0;

  @override
  Future<Appearance> load() async => kept;

  @override
  Future<void> save(Appearance appearance) async {
    kept = appearance;
    saves++;
  }
}

void main() {
  group('FileAppearanceStore', () {
    late Directory dir;
    late FileAppearanceStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('appearance');
      store = FileAppearanceStore(() async => dir);
    });
    tearDown(() => dir.delete(recursive: true));

    test('nothing kept: Phone', () async {
      expect(await store.load(), Appearance.phone);
    });

    test('keeps the setting', () async {
      await store.save(Appearance.dark);
      expect(await FileAppearanceStore(() async => dir).load(), Appearance.dark);
    });

    test('a file it can\'t read: Phone', () async {
      await File('${dir.path}/${FileAppearanceStore.fileName}').writeAsString('not json');
      expect(await store.load(), Appearance.phone);
    });

    test('no folder (as in tests): Phone, and no error', () async {
      final none = FileAppearanceStore(() async => throw const FileSystemException('no folder'));
      expect(await none.load(), Appearance.phone);
    });
  });

  group('the Appearance setting', () {
    test('starts as Phone, then takes the setting kept', () async {
      final c = ProviderContainer(overrides: [
        appearanceStoreProvider.overrideWithValue(MemoryAppearanceStore(Appearance.light)),
      ]);
      addTearDown(c.dispose);
      c.listen(appearanceProvider, (_, _) {});
      expect(c.read(appearanceProvider), Appearance.phone);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(appearanceProvider), Appearance.light);
    });

    test('a choice is kept', () {
      final store = MemoryAppearanceStore();
      final c = ProviderContainer(overrides: [appearanceStoreProvider.overrideWithValue(store)]);
      addTearDown(c.dispose);
      c.read(appearanceProvider.notifier).choose(Appearance.dark);
      expect((c.read(appearanceProvider), store.kept), (Appearance.dark, Appearance.dark));
    });

    test('Phone, Light and Dark: the system, light and dark theme modes', () {
      expect([for (final a in Appearance.values) themeModeOf(a)], [ThemeMode.system, ThemeMode.light, ThemeMode.dark]);
    });
  });

  group('the themes', () {
    test('dark: charcoal background, amber primary', () {
      final t = AppTheme.dark();
      expect((t.brightness, t.scaffoldBackgroundColor, t.colorScheme.primary),
          (Brightness.dark, AppPalette.dark.background, AppPalette.dark.primary));
    });

    test('light: off-white background, darker amber', () {
      final t = AppTheme.light();
      expect((t.brightness, t.scaffoldBackgroundColor, t.colorScheme.primary),
          (Brightness.light, AppPalette.light.background, AppPalette.light.primary));
    });

    testWidgets('a camera screen is dark inside a light app', (tester) async {
      late Brightness seen;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: CameraTheme(child: Builder(builder: (context) {
          seen = Theme.of(context).brightness;
          return const SizedBox();
        })),
      ));
      expect(seen, Brightness.dark);
    });
  });
}
