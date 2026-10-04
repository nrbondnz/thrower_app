import 'package:flutter/material.dart';

import 'debug_target_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thrower App')),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DebugTargetScreen()),
          ),
          child: const Text('Scoring test target'),
        ),
      ),
    );
  }
}
