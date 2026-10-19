import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/auth/auth_service.dart';
import 'package:thrower_app/camera/target_camera.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/account_screen.dart';
import 'package:thrower_app/ui/home_screen.dart';

/// An [AuthService] with a fixed user, counting sign-outs.
class FakeAuthService implements AuthService {
  FakeAuthService([this.currentUser]);

  @override
  AppUser? currentUser;
  var signOuts = 0;

  @override
  Stream<AppUser?> authStateChanges() => const Stream.empty();

  @override
  Future<void> signOut() async => signOuts++;
}

/// App user accounts story, Task 2: Home → Account, only when the build is
/// connected to the accounts backend; nothing else changes.
void main() {
  Future<void> pumpHome(WidgetTester tester, {AuthService? auth}) => tester.pumpWidget(ProviderScope(
        overrides: [
          cameraProvider.overrideWith((ref) => Completer<TargetCamera>().future),
          if (auth != null) authServiceProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ));

  testWidgets('a build without accounts: no Account button, Home as before', (tester) async {
    await pumpHome(tester);
    expect(find.byKey(const Key('homeAccount')), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
  });

  testWidgets('a build with accounts: an Account button on Home', (tester) async {
    await pumpHome(tester, auth: FakeAuthService());
    expect(find.byKey(const Key('homeAccount')), findsOneWidget);
  });

  testWidgets('the Account screen without accounts says so', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: AccountScreen())));
    expect(find.text('Accounts are not available in this build.'), findsOneWidget);
  });

  group('signed in', () {
    testWidgets('shows who is signed in, and that scoring works either way', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AccountDetails(user: const AppUser(id: 'sub-1', displayName: 'jo@example.com'), onSignOut: () async {}),
        ),
      ));
      expect(tester.widget<Text>(find.byKey(const Key('accountEmail'))).data, 'jo@example.com');
      expect(find.textContaining('Scoring works the same signed in or out.'), findsOneWidget);
    });

    testWidgets('Sign out signs out', (tester) async {
      final auth = FakeAuthService(const AppUser(id: 'sub-1', displayName: 'jo@example.com'));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AccountDetails(user: auth.currentUser, onSignOut: auth.signOut)),
      ));
      await tester.tap(find.byKey(const Key('accountSignOut')));
      expect(auth.signOuts, 1);
    });
  });
}
