import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../settings/appearance_store.dart';
import 'account_screen.dart';
import 'app_shell.dart';
import 'calibration_screen.dart';
import 'debug_target_screen.dart';
import 'instructions.dart';
import 'live_test_screen.dart';
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
          const SectionHeading('Help'),
          Card(
            child: tile('setupInstructions', Icons.menu_book_outlined, 'Instructions',
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
                const Divider(height: 1),
                tile('setupLiveTest', Icons.play_circle_outline, 'Live test',
                    'Play or Quick draw on a recording', const LiveTestScreen()),
                const Divider(height: 1),
                tile('setupTestTarget', Icons.adjust, 'Scoring test target', 'Tap a target to see its score',
                    const DebugTargetScreen()),
              ],
            ),
          ),
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
