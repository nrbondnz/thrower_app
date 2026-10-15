import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/recorded_camera.dart';
import '../providers.dart';
import 'calibration_screen.dart';
import 'play_screen.dart';
import 'quick_draw_screen.dart';

/// Live test: plays a recording of a real board in place of the camera,
/// through the same calibrate → Play screens, analysed live as it plays.
/// Choose a target, calibrate it (the recording waits on its first frame),
/// then Play (the recording starts from the beginning).
///
/// Leaving this screen goes back to the phone's camera, with a fresh
/// calibration and game.
class LiveTestScreen extends ConsumerWidget {
  const LiveTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(recordingChoiceProvider);
    // Keeps the recording loaded while moving between calibrate and Play.
    if (chosen != null) ref.watch(cameraProvider);
    final calibrated = ref.watch(calibrationProvider)?.locked ?? false;

    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(recordingChoiceProvider.notifier).use(null);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Live test')),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Plays a video of a real board instead of the camera. The app analyses it live, '
                'as it would the camera: calibrate the target, then Play.',
              ),
              const SizedBox(height: 16),
              for (final recording in liveTestRecordings)
                Card(
                  key: Key('liveTest-${recording.name}'),
                  child: RadioListTile<Recording>(
                    value: recording,
                    // ignore: deprecated_member_use
                    groupValue: chosen,
                    // ignore: deprecated_member_use
                    onChanged: (r) => ref.read(recordingChoiceProvider.notifier).use(r),
                    title: Text(recording.name),
                    subtitle: Text(recording.description),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: chosen == null ? null : () => open(const CalibrationScreen()),
                child: Text(calibrated ? '1. Calibrate (done)' : '1. Calibrate target'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: chosen == null || !calibrated ? null : () => open(const PlayScreen()),
                child: const Text('2. Play'),
              ),
              const SizedBox(height: 32),
              Text('Quick draw', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Two throwers, one board each, after a countdown. Plays full screen, with sound.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => open(const QuickDrawScreen()),
                child: const Text('Quick draw'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
