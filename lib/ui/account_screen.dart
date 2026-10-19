import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';
import '../providers.dart';

/// Home → Account (app user accounts story, Task 2): sign in or create an
/// account with Amplify's ready-made screens (`amplify_authenticator`, as
/// WhereWillWeVisit), then see who's signed in and sign out. Only shown when
/// the build is connected to the accounts backend; signing in is never needed
/// to score.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: auth == null
          ? const Center(child: Text('Accounts are not available in this build.'))
          : AuthenticatedView(child: _SignedInUser(auth)),
    );
  }
}

/// Follows [auth]'s user while signed in.
class _SignedInUser extends StatelessWidget {
  const _SignedInUser(this.auth);

  final AuthService auth;

  @override
  Widget build(BuildContext context) => StreamBuilder<AppUser?>(
        stream: auth.authStateChanges(),
        initialData: auth.currentUser,
        builder: (context, snapshot) => AccountDetails(user: snapshot.data, onSignOut: auth.signOut),
      );
}

/// Who's signed in, what the account is for, and Sign out.
class AccountDetails extends StatelessWidget {
  const AccountDetails({super.key, required this.user, required this.onSignOut});

  final AppUser? user;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Signed in as', style: theme.textTheme.bodySmall),
        Text(user?.displayName ?? '…', key: const Key('accountEmail'), style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        const Text('Scoring works the same signed in or out. Backing up your history and player names to your '
            'account comes next.'),
        const SizedBox(height: 24),
        OutlinedButton(
          key: const Key('accountSignOut'),
          onPressed: onSignOut,
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
