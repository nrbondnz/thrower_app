import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/account_screen.dart';
import 'package:thrower_app/ui/setup_screen.dart';
import 'package:thrower_app/ui/support_links.dart';

import '../history/memory_game_history.dart';

/// Compliance story (Nigel, 2026-10-23): Setup → Help and support, as
/// WhereWillWeVisit's support page.
void main() {
  late List<Uri> opened;
  late bool opens;

  setUp(() {
    opened = [];
    opens = true;
  });

  Future<void> pumpSetup(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameHistoryProvider.overrideWithValue(MemoryGameHistory()),
        linkOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return opens;
        }),
      ],
      child: const MaterialApp(home: SetupScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapTile(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(find.byKey(Key(key)), 100);
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  final links = [
    ('supportEmail', SupportLinks.mail),
    ('supportHelpPage', Uri.parse('https://knifeandaxethrower.com/support')),
    ('supportPrivacy', Uri.parse('https://knifeandaxethrower.com/privacy')),
    ('supportTerms', Uri.parse('https://knifeandaxethrower.com/terms')),
  ];
  for (final (key, uri) in links) {
    testWidgets('$key opens $uri', (tester) async {
      await pumpSetup(tester);
      await tapTile(tester, key);
      expect(opened, [uri]);
    });
  }

  test('Support emails the support address', () {
    expect((SupportLinks.mail.scheme, SupportLinks.mail.path), ('mailto', 'kaat-support@knifeandaxethrower.com'));
  });

  testWidgets("a link that can't open says where it is", (tester) async {
    opens = false;
    await pumpSetup(tester);
    await tapTile(tester, 'supportPrivacy');
    expect(find.textContaining('https://knifeandaxethrower.com/privacy'), findsOneWidget);
  });

  testWidgets('Delete account, with no accounts in this build: there is no account, and the website page',
      (tester) async {
    await pumpSetup(tester);
    await tapTile(tester, 'supportDeleteAccount');
    expect(find.byType(NoAccountScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('noAccountWebsite')));
    await tester.pump();
    expect(opened, [Uri.parse('https://knifeandaxethrower.com/delete-account')]);
  });

  // The Account screen needs the app's Authenticator to draw, so the choice
  // is tested on its own.
  test('Delete account, in a build with accounts: the Account screen (with Delete account)', () {
    expect(deleteAccountScreen(accounts: true), isA<AccountScreen>());
    expect(deleteAccountScreen(accounts: false), isA<NoAccountScreen>());
  });
}
