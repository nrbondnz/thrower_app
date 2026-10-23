import 'package:flutter/material.dart';

import '../../scoring/target_model.dart';
import '../target_painter.dart';

/// The shared pieces of the new look (docs/thrower/AppDesign/Components.md).

/// A card in place of a plain button: an icon, a title in capitals and a
/// short line under it. The whole card can be tapped.
class ActionCard extends StatelessWidget {
  const ActionCard({super.key, required this.icon, required this.title, required this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 28),
              const SizedBox(height: 12),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A big number with a small label under it: the numbers are the focus
/// (docs/thrower/AppDesign/Typography and Numbers.md).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// A row of [StatTile]s, evenly spread.
class StatRow extends StatelessWidget {
  const StatRow(this.tiles, {super.key});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) => Row(
        children: [for (final t in tiles) Expanded(child: t)],
      );
}

final _katta = TargetModel.katta();

/// The board drawn small, in its painted red and wood: the app's mark.
class TargetMark extends StatelessWidget {
  const TargetMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: TargetPainter(model: _katta)),
      );
}

/// Small, bold, spaced capitals above a group ("QUICK ACTIONS").
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
