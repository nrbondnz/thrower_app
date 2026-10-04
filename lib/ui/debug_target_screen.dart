import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../scoring/target_model.dart';
import 'target_painter.dart';

/// Normalised half-width of the simulated blade, so taps near a line show the
/// line-touch rule at work.
const debugBladeHalfWidth = 0.03;

/// Tap anywhere on a drawn target to see the score for that point. Used to
/// check the scoring domain before the camera and vision layers exist.
class DebugTargetScreen extends ConsumerStatefulWidget {
  const DebugTargetScreen({super.key});

  @override
  ConsumerState<DebugTargetScreen> createState() => _DebugTargetScreenState();
}

class _DebugTargetScreenState extends ConsumerState<DebugTargetScreen> {
  LineTouchRule? _rule;
  TargetPoint? _hit;

  @override
  Widget build(BuildContext context) {
    final base = ref.watch(targetModelProvider);
    final rule = _rule ?? base.lineTouchRule;
    final model = TargetModel(rings: base.rings, lineTouchRule: rule);
    final hit = _hit;

    return Scaffold(
      appBar: AppBar(title: const Text('Scoring test target')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<LineTouchRule>(
              segments: const [
                ButtonSegment(value: LineTouchRule.higher, label: Text('Line = higher')),
                ButtonSegment(value: LineTouchRule.lower, label: Text('Line = lower')),
              ],
              selected: {rule},
              onSelectionChanged: (s) => setState(() => _rule = s.single),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return GestureDetector(
                  key: const Key('debugTarget'),
                  onTapDown: (d) {
                    final scale = TargetPainter.scaleFor(size);
                    final offset = (d.localPosition - size.center(Offset.zero)) / scale;
                    setState(() => _hit = TargetPoint(offset.dx, offset.dy));
                  },
                  child: CustomPaint(
                    size: size,
                    painter: TargetPainter(model: model, hit: hit, markerRadius: debugBladeHalfWidth),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              hit == null
                  ? 'Tap the target'
                  : 'Score: ${model.scoreAt(hit, bladeHalfWidth: debugBladeHalfWidth)}',
              key: const Key('scoreText'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ],
      ),
    );
  }
}
