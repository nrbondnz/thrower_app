import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'camera_view.dart';
import 'quick_draw_boards.dart';

/// Quick draw with the phone's live camera (Home → Quick draw): two throwers,
/// one board each, side by side, throwing on the app's start signal. The
/// camera fills the screen (system bars hidden); the user taps the centre of
/// Player 1's board, then Player 2's, and locks them. The start signal, timing
/// and the result come next (`docs/thrower/stories/
/// story-checkpoint-live-quick-draw.md`). The recording version is
/// `QuickDrawScreen` (Live test → Quick draw).
class LiveQuickDrawScreen extends ConsumerStatefulWidget {
  const LiveQuickDrawScreen({super.key});

  @override
  ConsumerState<LiveQuickDrawScreen> createState() => _LiveQuickDrawScreenState();
}

class _LiveQuickDrawScreenState extends ConsumerState<LiveQuickDrawScreen> with BoardChoosing {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targets = ref.watch(quickDrawTargetsProvider);
    final notifier = ref.read(quickDrawTargetsProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraView(
            camera: liveQuickDrawCameraProvider,
            overlayBuilder: (context, camera) => BoardsOverlay(
              targets: targets,
              onTap: targets.complete || searching ? null : (tap) => findBoardAt(camera, tap),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    key: const Key('quickDrawBack'),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      quickDrawLine(choosingInstruction(targets, locked: 'Boards locked.')),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (targets.boards.isNotEmpty)
                            OutlinedButton(
                              key: const Key('quickDrawStartAgain'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.black54),
                              onPressed: notifier.clear,
                              child: const Text('Start again'),
                            ),
                          if (targets.complete && !targets.locked)
                            FilledButton(
                              key: const Key('quickDrawLock'),
                              onPressed: notifier.lock,
                              child: const Text('Lock boards'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
