import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_service.dart';
import 'camera/live_camera.dart';
import 'scoring/target_model.dart';
import 'vision/target_calibration.dart';

/// Wiring for the app's layers. Tests override any of these with fakes.

final targetModelProvider = Provider<TargetModel>((ref) => TargetModel.ikthof());

/// Normalised radii of the ring boundaries inside the target (every ring's
/// outer edge except the outermost), which the ring finder looks for.
final ringBoundaryRadiiProvider = Provider<List<double>>((ref) {
  final rings = ref.watch(targetModelProvider).rings;
  return [for (final r in rings.take(rings.length - 1)) r.outerRadius];
});

/// The open back camera. Released as soon as nothing is watching it (e.g. the
/// camera screen closes or the app goes to the background).
///
/// Never retried automatically: on Android a retry after "Don't allow" would
/// show the permission prompt again. The user retries from the error view.
final liveCameraProvider = FutureProvider.autoDispose<LiveCamera>(
  (ref) async {
    final camera = await LiveCamera.open();
    ref.onDispose(camera.dispose);
    return camera;
  },
  retry: (retryCount, error) => null,
);

/// The target calibration for this session: found, adjusted, then locked.
/// Not auto-disposed, so it survives leaving and returning to the screen.
class CalibrationState {
  const CalibrationState(this.calibration, {this.locked = false});

  final TargetCalibration calibration;
  final bool locked;
}

class CalibrationNotifier extends Notifier<CalibrationState?> {
  @override
  CalibrationState? build() => null;

  /// A new (unlocked) calibration, e.g. from "Find target".
  void start(TargetCalibration calibration) => state = CalibrationState(calibration);

  /// A hand adjustment. Ignored once locked.
  void adjust(TargetCalibration calibration) {
    if (state case CalibrationState(locked: false)) state = CalibrationState(calibration);
  }

  void lock() {
    if (state case final s?) state = CalibrationState(s.calibration, locked: true);
  }

  /// "Re-calibrate": keep the outline but allow changes again.
  void unlock() {
    if (state case final s?) state = CalibrationState(s.calibration);
  }
}

final calibrationProvider = NotifierProvider<CalibrationNotifier, CalibrationState?>(CalibrationNotifier.new);

/// No auth provider is chosen yet, so this must be overridden before use.
final authServiceProvider = Provider<AuthService>(
  (ref) => throw UnimplementedError('Auth provider not chosen yet (backend deferred)'),
);
