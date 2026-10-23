import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/game_history.dart';
import '../history/test_sessions.dart';
import '../providers.dart';
import '../settings/appearance_store.dart';
import 'account_screen.dart';
import 'app_shell.dart';
import 'calibration_screen.dart';
import 'debug_target_screen.dart';
import 'instructions.dart';
import 'live_test_screen.dart';
import 'support_links.dart';
import 'theme/widgets.dart';

/// The Setup tab: the technical tools together and out of the way, the
/// Instructions, Appearance and the Account
/// (docs/thrower/AppDesign/Navigation and Structure.md → Setup).
class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    ListTile tile(String key, IconData icon, String title, String subtitle, Widget screen) => ListTile(
          key: Key(key),
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openScreen(context, ref, screen),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Setup')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SectionHeading('Help and support'),
          HelpAndSupportCard(
            instructions: tile('setupInstructions', Icons.menu_book_outlined, 'Instructions',
                'Setting up the phone, throwing, scoring', const InstructionsScreen()),
          ),
          const SectionHeading('Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<Appearance>(
                key: const Key('setupAppearance'),
                segments: [
                  for (final a in Appearance.values) ButtonSegment(value: a, label: Text(a.label)),
                ],
                selected: {appearance},
                onSelectionChanged: (chosen) => ref.read(appearanceProvider.notifier).choose(chosen.single),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text('Phone: light or dark as the phone is set. The camera screens are always dark.'),
          ),
          const SectionHeading('Tools'),
          Card(
            child: Column(
              children: [
                tile('setupCalibrate', Icons.center_focus_strong_outlined, 'Calibrate target',
                    'Find the rings and lock them', const CalibrationScreen()),
                // Test builds only (store-release hygiene, backlog #6,
                // 2026-10-23): Live test plays recordings of real people;
                // the scoring test target is a developer's check.
                if (ref.watch(testToolsProvider)) ...[
                  const Divider(height: 1),
                  tile('setupLiveTest', Icons.play_circle_outline, 'Live test',
                      'Play or Quick draw on a recording', const LiveTestScreen()),
                  const Divider(height: 1),
                  tile('setupTestTarget', Icons.adjust, 'Scoring test target', 'Tap a target to see its score',
                      const DebugTargetScreen()),
                ],
              ],
            ),
          ),
          if (ref.watch(testToolsProvider)) ...[
            const SectionHeading('Test sessions (test build only)'),
            const TestSessionsCard(),
          ],
          // Accounts (stage 2): only in a build connected to the backend.
          if (ref.watch(authServiceProvider) != null) ...[
            const SectionHeading('Account'),
            Card(
              child: tile('setupAccount', Icons.account_circle_outlined, 'Account', 'Sign in, backup',
                  const AccountScreen()),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Test builds only: **Add 10 test sessions** (new random sessions that can
/// be posted, made each time) and **Remove test sessions**
/// (posting-from-history story, Nigel 2026-10-23). They're marked Test in
/// History and left out of the stats.
class TestSessionsCard extends ConsumerStatefulWidget {
  const TestSessionsCard({super.key});

  @override
  ConsumerState<TestSessionsCard> createState() => _TestSessionsCardState();
}

class _TestSessionsCardState extends ConsumerState<TestSessionsCard> {
  var _busy = false;

  Future<void> _run(Future<String> Function(GameHistory history) work) async {
    setState(() => _busy = true);
    String said;
    try {
      said = await work(ref.read(gameHistoryProvider));
    } on GameHistoryException catch (e) {
      said = "Couldn't change the history: ${e.message}";
    }
    ref.invalidate(keptGamesProvider);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(said)));
  }

  Future<String> _add(GameHistory history) async {
    final sessions = makeTestSessions(ref.read(clockProvider)());
    for (final s in sessions) {
      await history.add(s);
    }
    return 'Added ${sessions.length} test sessions to History.';
  }

  Future<String> _remove(GameHistory history) async {
    final tests = (await history.load()).where((g) => g.test).toList();
    for (final g in tests) {
      await history.delete(g.id);
    }
    return 'Removed ${tests.length} test sessions.';
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Column(
          children: [
            ListTile(
              key: const Key('setupAddTestSessions'),
              enabled: !_busy,
              leading: const Icon(Icons.science_outlined),
              title: const Text('Add 10 test sessions'),
              subtitle: const Text('New random sessions, this week, that can be posted'),
              onTap: () => _run(_add),
            ),
            const Divider(height: 1),
            ListTile(
              key: const Key('setupRemoveTestSessions'),
              enabled: !_busy,
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Remove test sessions'),
              onTap: () => _run(_remove),
            ),
          ],
        ),
      );
}
