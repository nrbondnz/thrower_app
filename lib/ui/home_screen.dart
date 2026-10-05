import 'package:flutter/material.dart';

import 'calibration_screen.dart';
import 'camera_screen.dart';
import 'debug_locator_screen.dart';
import 'debug_target_screen.dart';

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
            FilledButton(
              onPressed: () => open(const CalibrationScreen()),
              child: const Text('Calibrate target'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => open(const CameraScreen()),
              child: const Text('Camera'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => open(const DebugTargetScreen()),
              child: const Text('Scoring test target'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => open(const DebugLocatorScreen()),
              child: const Text('Ring finder test'),
            ),
          ],
        ),
      ),
    );
  }
}
