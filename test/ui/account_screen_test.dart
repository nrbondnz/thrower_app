import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/auth/auth_service.dart';
import 'package:thrower_app/camera/target_camera.dart';
import 'package:thrower_app/providers.dart';
import 'package:thrower_app/ui/account_screen.dart';
import 'package:thrower_app/ui/setup_screen.dart';

/// An [AuthService] with a fixed user, counting sign-outs.
class FakeAuthService implements AuthService {
  FakeAuthService([this.currentUser]);

  @override
  AppUser? currentUser;
  var signOuts = 0;
  var deleted = false;
  var failDelete = false;

  @override
  Stream<AppUser?> authStateChanges() => const Stream.empty();

  @override
  Future<void> signOut() async => signOuts++;

  @override
  Future<void> deleteUser() async {
    if (failDelete) throw Exception('no signal');
    deleted = true;
    currentUser = null;
  }
}

/// App user accounts story, Task 2: Home → Account, only when the build is
/// connected to the accounts backend; nothing else changes.
void main() {
  Future<void> pumpHome(WidgetTester tester, {AuthService? auth}) => tester.pumpWidget(ProviderScope(
        overrides: [
          cameraProvider.overrideWith((ref) => Completer<TargetCamera>().future),
          if (auth != null) authServiceProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(home: SetupScreen()),
      ));

  // App design (2026-10-23): the Account moved from Home to Setup.
  testWidgets('a build without accounts: no Account in Setup', (tester) async {
    await pumpHome(tester);
    expect(find.byKey(const Key('setupAccount')), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const Key('setupCalibrate')), 100);
    expect(find.byKey(const Key('setupCalibrate')), findsOneWidget);
  });

  testWidgets('a build with accounts: Account in Setup', (tester) async {
    await pumpHome(tester, auth: FakeAuthService());
    await tester.scrollUntilVisible(find.byKey(const Key('setupAccount')), 100);
    await tester.ensureVisible(find.byKey(const Key('setupAccount')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('setupAccount')), findsOneWidget);
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

  // Task 4: the backup.
  group('backup', () {
    test('what the screen says', () {
      expect(backupText(const BackupRunning()), 'Backing up…');
      expect(backupText(const BackupDone((downloaded: 0, uploaded: 0))), 'Your games and player names are backed up.');
      expect(backupText(const BackupDone((downloaded: 2, uploaded: 1))), 'Backed up: 1 game sent, 2 brought to this phone.');
      expect(backupText(const BackupFailed('x')), contains('Your games are safe on this phone.'));
    });

    testWidgets('Back up now: offered once a backup has run, not while one is running', (tester) async {
      var runs = 0;
      Future<void> pump(BackupStatus status) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: AccountDetails(
                user: const AppUser(id: 'sub-1', displayName: 'jo@example.com'),
                onSignOut: () async {},
                backup: status,
                onBackUp: () async => runs++,
              ),
            ),
          ));
      await pump(const BackupRunning());
      expect(tester.widget<TextButton>(find.byKey(const Key('accountBackUpNow'))).onPressed, isNull);
      await pump(const BackupFailed('no signal'));
      await tester.tap(find.byKey(const Key('accountBackUpNow')));
      expect(runs, 1);
      await pump(const BackupOff());
      expect(find.byKey(const Key('accountBackUpNow')), findsNothing);
    });
  });

  // Task 5: Delete account (asks first).
  group('Delete account', () {
    Future<List<int>> pump(WidgetTester tester, {bool fail = false}) async {
      final calls = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => AccountDetails(
              user: const AppUser(id: 'sub-1', displayName: 'jo@example.com'),
              onSignOut: () async {},
              onDelete: () => confirmAndDeleteAccount(context, () async {
                calls.add(1);
                if (fail) throw Exception('no signal');
              }),
            ),
          ),
        ),
      ));
      return calls;
    }

    testWidgets('asks first; Cancel deletes nothing', (tester) async {
      final calls = await pump(tester);
      await tester.tap(find.byKey(const Key('accountDelete')));
      await tester.pumpAndSettle();
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(find.textContaining('The games and names on this phone stay.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });

    testWidgets('confirmed: deletes', (tester) async {
      final calls = await pump(tester);
      await tester.tap(find.byKey(const Key('accountDelete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accountDeleteConfirm')));
      await tester.pumpAndSettle();
      expect(calls, [1]);
    });

    testWidgets("no signal: says it couldn't, to try again", (tester) async {
      await pump(tester, fail: true);
      await tester.tap(find.byKey(const Key('accountDelete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accountDeleteConfirm')));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't delete your account just now"), findsOneWidget);
    });
  });
}

