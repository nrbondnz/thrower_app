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

class ThrowerApp extends StatelessWidget {
  const ThrowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thrower App',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: targetRed)),
      home: const HomeScreen(),
    );
  }
}
