import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/auth/amplify_accounts.dart';
import 'package:thrower_app/providers.dart';

/// An asset bundle holding only [assets] (path → text).
class TextBundle extends CachingAssetBundle {
  TextBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final text = assets[key];
    if (text == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(utf8.encode(text));
  }
}

/// App user accounts story, Task 1: the app connects to its Amplify backend
/// only when the build has the backend's settings; otherwise it runs signed
/// out, as it always has.
void main() {
  group('loadAmplifyOutputs', () {
    test('no settings in the build (no backend connected yet): none', () async {
      expect(await loadAmplifyOutputs(TextBundle({})), isNull);
    });

    test('an empty settings file: none', () async {
      expect(await loadAmplifyOutputs(TextBundle({amplifyOutputsAsset: '  \n'})), isNull);
    });

    test('settings present: read as they are', () async {
      const outputs = '{"version": "1.4", "auth": {"aws_region": "eu-west-2"}}';
      expect(await loadAmplifyOutputs(TextBundle({amplifyOutputsAsset: outputs})), outputs);
    });
  });

  test('without settings, no accounts: the app runs signed out', () async {
    expect(await connectAccounts(null), isNull);
  });

  test('accounts are off unless main connects them', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(authServiceProvider), isNull);
  });
}
