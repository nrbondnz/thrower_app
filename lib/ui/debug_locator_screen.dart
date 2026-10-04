import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../vision/colour_ring_locator.dart';
import '../vision/decode_image.dart';
import '../vision/ellipse.dart';
import '../vision/rgb_image.dart';
import '../vision/synthetic_target.dart';
import '../vision/target_locator.dart';

/// A test image for the ring finder: the reference photo, or a synthetic
/// target with a known answer.
class LocatorSample {
  const LocatorSample(this.label, this.load);

  final String label;
  final Future<RgbImage> Function() load;
}

final locatorSamples = [
  LocatorSample('Reference photo', () => _loadAsset('assets/debug/target-example.jpg')),
  LocatorSample('Synthetic: straight on', () async => SyntheticTarget().render()),
  LocatorSample('Synthetic: 40° side', () async => SyntheticTarget(viewAngleDegrees: 40).render()),
  LocatorSample(
    'Synthetic: 55°, tilted, knives',
    () async => SyntheticTarget(
      viewAngleDegrees: 55,
      rotationDegrees: 20,
      knives: [(0.1, 0.05), (-0.5, -0.3), (0.45, 0.5)],
    ).render(),
  ),
];

// Top-level so the background isolate is sent only the data, never a closure
// over widget state (which can't be sent).
Future<RgbImage> _loadAsset(String path) async {
  final bytes = (await rootBundle.load(path)).buffer.asUint8List();
  return compute(_decode, bytes);
}

RgbImage _decode(Uint8List bytes) => decodeToRgb(bytes)!;

TargetLocateResult _locate((List<double>, RgbImage) input) =>
    ColourRingLocator(boundaryRadii: input.$1).locate(input.$2);

/// Ring finder check: pick a test image, see the fitted ring edges drawn on it.
class DebugLocatorScreen extends ConsumerStatefulWidget {
  const DebugLocatorScreen({super.key});

  @override
  ConsumerState<DebugLocatorScreen> createState() => _DebugLocatorScreenState();
}

class _DebugLocatorScreenState extends ConsumerState<DebugLocatorScreen> {
  int _selected = 0;
  ui.Image? _image;
  TargetLocateResult? _result;
  int? _millis;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final index = _selected;
    setState(() {
      _image = null;
      _result = null;
    });
    final rgb = await locatorSamples[index].load();
    final boundaries = ref.read(ringBoundaryRadiiProvider);
    final stopwatch = Stopwatch()..start();
    final result = await compute(_locate, (boundaries, rgb));
    final millis = stopwatch.elapsedMilliseconds;
    final image = await _toUiImage(rgb);
    if (!mounted || index != _selected) return;
    setState(() {
      _image = image;
      _result = result;
      _millis = millis;
    });
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Ring finder test')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                for (var i = 0; i < locatorSamples.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(locatorSamples[i].label),
                      selected: i == _selected,
                      onSelected: (_) {
                        setState(() => _selected = i);
                        _run();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: image == null || result == null
                ? const Center(child: CircularProgressIndicator())
                : FittedBox(
                    child: SizedBox(
                      width: image.width.toDouble(),
                      height: image.height.toDouble(),
                      child: CustomPaint(painter: LocatorOverlayPainter(image: image, result: result)),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              switch (result) {
                null => 'Finding rings…',
                TargetFound(:final confidence) =>
                  'Found: confidence ${(confidence * 100).round()}%, $_millis ms',
                TargetNotFound(:final reason) => 'Not found: $reason',
              },
              key: const Key('locatorResult'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

Future<ui.Image> _toUiImage(RgbImage rgb) {
  final rgba = Uint8List(rgb.width * rgb.height * 4);
  for (var i = 0, j = 0; i < rgb.pixels.length; i += 3, j += 4) {
    rgba[j] = rgb.pixels[i];
    rgba[j + 1] = rgb.pixels[i + 1];
    rgba[j + 2] = rgb.pixels[i + 2];
    rgba[j + 3] = 255;
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, rgb.width, rgb.height, ui.PixelFormat.rgba8888, completer.complete);
  return completer.future;
}

/// Draws the image, the edge points (yellow) and fitted ellipses: blue when
/// found, magenta for a rejected attempt.
class LocatorOverlayPainter extends CustomPainter {
  LocatorOverlayPainter({required this.image, required this.result});

  final ui.Image image;
  final TargetLocateResult result;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
    final (ellipses, points, colour) = switch (result) {
      TargetFound(:final boundaries, :final outer, :final boundaryPoints) =>
        ([...boundaries.values, outer], boundaryPoints, Colors.blueAccent),
      TargetNotFound(:final attempted, :final attemptedPoints) =>
        (attempted.values.toList(), attemptedPoints, Colors.purpleAccent),
    };
    final dot = Paint()..color = Colors.yellow;
    for (final list in points.values) {
      for (final p in list) {
        canvas.drawCircle(Offset(p.x, p.y), 2.5, dot);
      }
    }
    final stroke = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final e in ellipses) {
      canvas.drawPath(_ellipsePath(e), stroke);
    }
  }

  Path _ellipsePath(Ellipse e) {
    final path = Path();
    for (var i = 0; i <= 120; i++) {
      final p = e.pointAt(2 * 3.141592653589793 * i / 120);
      i == 0 ? path.moveTo(p.x, p.y) : path.lineTo(p.x, p.y);
    }
    return path;
  }

  @override
  bool shouldRepaint(LocatorOverlayPainter old) => old.image != image || old.result != result;
}
