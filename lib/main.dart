import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/home_screen.dart';
import 'ui/target_painter.dart';

void main() {
  runApp(const ProviderScope(child: ThrowerApp()));
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
