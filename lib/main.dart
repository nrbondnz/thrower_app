import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/amplify_accounts.dart';
import 'auth/amplify_backup.dart';
import 'providers.dart';
import 'ui/home_screen.dart';
import 'ui/target_painter.dart';

/// Connects to the accounts backend if this build has its settings
/// ([connectAccounts]); either way the app starts as before.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final outputs = await loadAmplifyOutputs(rootBundle);
  final accounts = await connectAccounts(outputs);
  runApp(ProviderScope(
    overrides: [
      if (accounts != null) authServiceProvider.overrideWithValue(accounts),
      // The backup (accounts Task 4), when the deployed backend has its data API.
      if (accounts != null && hasBackup(outputs!))
        backupFactoryProvider.overrideWithValue((userId) {
          final backup = AmplifyBackup(userId);
          return (games: backup, names: backup, erase: backup.erase);
        }),
    ],
    child: const ThrowerApp(),
  ));
}

class ThrowerApp extends ConsumerWidget {
  const ThrowerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(authServiceProvider) != null;
    // Keeps the backup running app-wide: signing in merges the phone's games
    // and names with the user's backup (accounts Task 4).
    ref.listen(backupStatusProvider, (_, _) {});
    final app = MaterialApp(
      title: 'Thrower App',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: targetRed)),
      home: const HomeScreen(),
    );
    // With accounts, the sign-in screens appear only inside the Account
    // screen's AuthenticatedView. Not Authenticator.builder(): that puts them
    // in front of the whole app whenever no one is signed in (Nigel saw it
    // on the Samsung, 2026-10-19), and signing in is never needed to score.
    return accounts ? Authenticator(child: app) : app;
  }
}
