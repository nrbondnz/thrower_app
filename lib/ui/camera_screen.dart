import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../camera/camera_source.dart';
import '../camera/frame_rate_meter.dart';
import '../camera/live_camera.dart';
import '../providers.dart';

/// Full-screen preview from the back camera. In debug builds it also shows the
/// frame rate, which proves frames are reaching the app for the vision layer.
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Camera')),
      // Above the system navigation bar / home indicator (see calibration_screen.dart).
      body: const SafeArea(top: false, child: CameraView()),
    );
  }
}

/// The back camera's preview, with permission errors, release on background
/// and re-open on return handled. [overlayBuilder] draws on top of the preview,
/// sized and positioned exactly over the camera image.
class CameraView extends ConsumerStatefulWidget {
  const CameraView({super.key, this.overlayBuilder});

  final Widget Function(BuildContext context, LiveCamera camera)? overlayBuilder;

  @override
  ConsumerState<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends ConsumerState<CameraView> with WidgetsBindingObserver {
  // Only `paused` releases the camera: the permission prompt makes the app
  // `inactive`, and releasing then would cancel the request it's waiting on.
  bool _backgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      setState(() => _backgrounded = true);
    } else if (state == AppLifecycleState.resumed && _backgrounded) {
      // Watching again re-opens the camera, which also retries after the user
      // turned access on in Settings.
      setState(() => _backgrounded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_backgrounded) return const SizedBox.expand();
    return ref.watch(liveCameraProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            debugPrint('Camera failed to start: $error\n$stack');
            return CameraErrorView(
              failure: error is CameraStartException ? error.failure : CameraFailure.unknown,
              detail: kDebugMode ? error.toString() : null,
              onRetry: () => ref.invalidate(liveCameraProvider),
            );
          },
          data: (camera) => Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: CameraPreview(camera.controller, child: widget.overlayBuilder?.call(context, camera)),
              ),
              if (kDebugMode) Positioned(top: 8, left: 8, child: FrameRateLabel(source: camera)),
            ],
          ),
        );
  }
}

class CameraErrorView extends StatelessWidget {
  const CameraErrorView({super.key, required this.failure, required this.onRetry, this.detail});

  final CameraFailure failure;
  final VoidCallback onRetry;

  /// Technical detail, shown in debug builds only.
  final String? detail;

  static String messageFor(CameraFailure failure) => switch (failure) {
        CameraFailure.denied => 'Thrower App needs the camera to watch your target.',
        CameraFailure.deniedPermanently =>
          'Camera access is off for Thrower App. Turn it on in Settings, then come back.',
        CameraFailure.restricted => 'Camera access is restricted on this device.',
        CameraFailure.noCamera => 'No camera was found on this device.',
        CameraFailure.unknown => "The camera couldn't start.",
      };

  @override
  Widget build(BuildContext context) {
    final canRetry = failure == CameraFailure.denied || failure == CameraFailure.unknown;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              messageFor(failure),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            if (detail != null) ...[
              const SizedBox(height: 12),
              Text(detail!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
            if (canRetry) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Debug-only label showing frames per second from a [CameraSource].
class FrameRateLabel extends StatefulWidget {
  const FrameRateLabel({super.key, required this.source});

  final CameraSource source;

  @override
  State<FrameRateLabel> createState() => _FrameRateLabelState();
}

class _FrameRateLabelState extends State<FrameRateLabel> {
  final _meter = FrameRateMeter();
  StreamSubscription<void>? _subscription;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _subscription = widget.source.frames().listen((f) => _meter.record(f.timestamp));
    _refresh = Timer.periodic(const Duration(milliseconds: 500), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text('${_meter.framesPerSecond} frames/s', style: const TextStyle(color: Colors.white)),
    );
  }
}
