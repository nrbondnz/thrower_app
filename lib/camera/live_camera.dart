import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';

import 'camera_frame.dart';
import 'camera_source.dart';

/// Why the camera couldn't start, in terms the UI can explain to the user.
enum CameraFailure {
  /// The user said no; the app may ask again (Android).
  denied,

  /// Previously denied; only the Settings app can turn it back on (iOS).
  deniedPermanently,

  /// Blocked by parental controls or device management (iOS).
  restricted,
  noCamera,
  unknown,
}

class CameraStartException implements Exception {
  const CameraStartException(this.failure, [this.detail]);

  final CameraFailure failure;
  final String? detail;

  @override
  String toString() => 'CameraStartException($failure, $detail)';
}

/// The phone's back camera. Audio is never recorded.
class LiveCamera implements CameraSource {
  LiveCamera._(this.controller);

  /// Exposed for [CameraPreview] only; other code should use [frames].
  final CameraController controller;

  final _clock = Stopwatch()..start();
  StreamController<CameraFrame>? _frames;

  static Future<LiveCamera> open() async {
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      throw CameraStartException(failureFor(e.code), '${e.code}: ${e.description}');
    } on Exception catch (e) {
      throw CameraStartException(CameraFailure.unknown, e.toString());
    }
    if (cameras.isEmpty) throw const CameraStartException(CameraFailure.noCamera);

    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      throw CameraStartException(failureFor(e.code), '${e.code}: ${e.description}');
    } on Exception catch (e) {
      await controller.dispose();
      throw CameraStartException(CameraFailure.unknown, e.toString());
    }
    return LiveCamera._(controller);
  }

  /// Maps the camera plugin's error codes (see its README) to [CameraFailure].
  static CameraFailure failureFor(String code) => switch (code) {
        'CameraAccessDenied' => CameraFailure.denied,
        'CameraAccessDeniedWithoutPrompt' => CameraFailure.deniedPermanently,
        'CameraAccessRestricted' => CameraFailure.restricted,
        _ => CameraFailure.unknown,
      };

  @override
  Stream<CameraFrame> frames() {
    return (_frames ??= StreamController<CameraFrame>.broadcast(
      onListen: () => controller.startImageStream((image) => _frames?.add(_toFrame(image))),
      onCancel: () async {
        if (controller.value.isStreamingImages) await controller.stopImageStream();
      },
    ))
        .stream;
  }

  CameraFrame _toFrame(CameraImage image) => CameraFrame(
        width: image.width,
        height: image.height,
        format: switch (image.format.group) {
          ImageFormatGroup.yuv420 => FrameFormat.yuv420,
          ImageFormatGroup.nv21 => FrameFormat.nv21,
          ImageFormatGroup.bgra8888 => FrameFormat.bgra8888,
          _ => FrameFormat.unknown,
        },
        planes: [
          for (final p in image.planes)
            FramePlane(bytes: p.bytes, bytesPerRow: p.bytesPerRow, bytesPerPixel: p.bytesPerPixel),
        ],
        timestamp: _clock.elapsed,
      );

  Future<void> dispose() async {
    await _frames?.close();
    _frames = null;
    await controller.dispose();
  }
}
