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

/// Follows [auth]'s user while signed in, and how backing up went.
class _SignedInUser extends ConsumerWidget {
  const _SignedInUser(this.auth);

  final AuthService auth;

  @override
  Widget build(BuildContext context, WidgetRef ref) => StreamBuilder<AppUser?>(
        stream: auth.authStateChanges(),
        initialData: auth.currentUser,
        builder: (context, snapshot) => AccountDetails(
          user: snapshot.data,
          onSignOut: auth.signOut,
          backup: ref.watch(backupStatusProvider),
          onBackUp: ref.read(backupStatusProvider.notifier).backUpNow,
          onDelete: () => confirmAndDeleteAccount(context, ref.read(deleteAccountProvider)),
        ),
      );
}

/// What the Account screen says about the backup.
String backupText(BackupStatus status) => switch (status) {
      BackupOff() => 'Backing up is not available in this build.',
      BackupRunning() => 'Backing up…',
      BackupDone(:final result) => result.downloaded + result.uploaded == 0
          ? 'Your games and player names are backed up.'
          : 'Backed up: ${result.uploaded} game${result.uploaded == 1 ? '' : 's'} sent, '
              '${result.downloaded} brought to this phone.',
      BackupFailed() => "Couldn't back up just now (no signal?). Your games are safe on this phone.",
    };

/// Who's signed in, what the account is for, and Sign out.
class AccountDetails extends StatelessWidget {
  const AccountDetails({
    super.key,
    required this.user,
    required this.onSignOut,
    this.backup = const BackupOff(),
    this.onBackUp,
    this.onDelete,
  });

  final AppUser? user;
  final Future<void> Function() onSignOut;
  final BackupStatus backup;
  final Future<void> Function()? onBackUp;

  /// Delete account (asks first).
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Signed in as', style: theme.textTheme.bodySmall),
        Text(user?.displayName ?? '…', key: const Key('accountEmail'), style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        const Text('Scoring works the same signed in or out. While you are signed in, your History and player '
            'names are backed up to your account, and come back if you sign in on a new phone.'),
        const SizedBox(height: 16),
        Text(backupText(backup), key: const Key('accountBackup')),
        if (onBackUp != null && backup is! BackupOff)
          TextButton(
            key: const Key('accountBackUpNow'),
            onPressed: backup is BackupRunning ? null : onBackUp,
            child: const Text('Back up now'),
          ),
        const SizedBox(height: 24),
        OutlinedButton(
          key: const Key('accountSignOut'),
          onPressed: onSignOut,
          child: const Text('Sign out'),
        ),
        if (onDelete != null) ...[
          const SizedBox(height: 32),
          TextButton(
            key: const Key('accountDelete'),
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            onPressed: onDelete,
            child: const Text('Delete account'),
          ),
        ],
      ],
    );
  }
}

/// Asks before deleting the account, then [delete]s it; says if it couldn't
/// (no signal: the account is still there).
Future<void> confirmAndDeleteAccount(BuildContext context, Future<void> Function() delete) async {
  final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete your account?'),
          content: const Text('Your account, and the games and player names backed up to it, are deleted for good. '
              'The games and names on this phone stay. This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            TextButton(
              key: const Key('accountDeleteConfirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete account'),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed) return;
  try {
    await delete();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't delete your account just now (no signal?). Please try again.")),
      );
    }
  }
}

