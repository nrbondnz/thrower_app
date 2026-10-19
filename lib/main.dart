import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/amplify_accounts.dart';
import 'providers.dart';
import 'ui/home_screen.dart';
import 'ui/target_painter.dart';

/// Connects to the accounts backend if this build has its settings
/// ([connectAccounts]); either way the app starts as before.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final accounts = await connectAccounts(await loadAmplifyOutputs(rootBundle));
  runApp(ProviderScope(
    overrides: [if (accounts != null) authServiceProvider.overrideWithValue(accounts)],
    child: const ThrowerApp(),
  ));
}

class ThrowerApp extends ConsumerWidget {
  const ThrowerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(authServiceProvider) != null;
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
