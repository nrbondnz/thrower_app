import 'package:flutter/material.dart';

import 'calibration_screen.dart';
import 'debug_target_screen.dart';
import 'instructions.dart';
import 'live_quick_draw_screen.dart';
import 'live_test_screen.dart';
import 'play_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(title: const Text('Thrower App')),
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
              onPressed: () => open(const PlayScreen()),
              child: const Text('Play'),
            ),
            const _Caption('Rounds on one target'),
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
