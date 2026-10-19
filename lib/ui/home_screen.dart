import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'account_screen.dart';

import 'calibration_screen.dart';
import 'debug_target_screen.dart';
import 'history_screen.dart';
import 'instructions.dart';
import 'live_quick_draw_screen.dart';
import 'live_test_screen.dart';
import 'play_setup_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thrower App'),
        actions: [
          // Accounts (stage 2): only in a build connected to the backend.
          if (ref.watch(authServiceProvider) != null)
            IconButton(
              key: const Key('homeAccount'),
              tooltip: 'Account',
              onPressed: () => open(const AccountScreen()),
              icon: const Icon(Icons.account_circle),
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: () => open(const InstructionsScreen()),
              child: const Text('Instructions'),
            ),
            const SizedBox(height: 16),
            // Two different games, so each says what it is (Nigel, 2026-10-15).
            FilledButton(
              onPressed: () => open(const PlaySetupScreen()),
              child: const Text('Play'),
            ),
            const _Caption('Rounds of 3 throws, 1 or 2 players'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => open(const HistoryScreen()),
              child: const Text('History'),
            ),
            const _Caption('Finished games of Play'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => open(const LiveQuickDrawScreen()),
              child: const Text('Quick draw'),
            ),
            const _Caption('Two throwers, on a start signal'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => open(const LiveTestScreen()),
              child: const Text('Live test'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => open(const CalibrationScreen()),
              child: const Text('Calibrate target'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => open(const DebugTargetScreen()),
              child: const Text('Scoring test target'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short line under a Home button saying what it's for.
class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}
