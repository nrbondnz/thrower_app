import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'setup_screen.dart';
import 'leaderboards_screen.dart';

/// The app's tabs (app-design story, Nigel 2026-10-23: a bottom bar):
/// Home, Leaderboards (in place of Throw: posting-from-history story, Nigel
/// 2026-10-23), History and Setup
/// (docs/thrower/AppDesign/Navigation and Structure.md). Throwing screens
/// open over the whole screen, bar included.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  /// The tabs, in order.
  static const home = 0, leaderboards = 1, history = 2, setup = 3;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  var _tab = AppShell.home;

  void _go(int tab) {
    // The kept sessions may have changed (a session finished, one deleted).
    ref.invalidate(keptGamesProvider);
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: switch (_tab) {
          AppShell.leaderboards => const LeaderboardsScreen(),
          AppShell.history => const HistoryScreen(),
          AppShell.setup => const SetupScreen(),
          _ => HomeScreen(onShowHistory: () => _go(AppShell.history)),
        },
        bottomNavigationBar: NavigationBar(
          key: const Key('appTabs'),
          selectedIndex: _tab,
          onDestinationSelected: _go,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events),
              label: 'Leaderboards',
            ),
            NavigationDestination(
                icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'History'),
            NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Setup'),
          ],
        ),
      );
}

/// Opens [screen] over the tabs; once back, the kept sessions are read
/// again (a session may have finished).
Future<void> openScreen(BuildContext context, WidgetRef ref, Widget screen) async {
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  ref.invalidate(keptGamesProvider);
}
