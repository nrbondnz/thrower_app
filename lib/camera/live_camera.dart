import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'camera_frame.dart';
import 'target_camera.dart';

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
class LiveCamera implements TargetCamera {
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
    final camera = LiveCamera._(controller);
    try {
      camera._maxZoom = math.max(1, await controller.getMaxZoomLevel());
    } on CameraException {
      // No zoom reported: stay at 1×.
    }
    return camera;
  }

  double _maxZoom = 1;
  double _zoom = 1;

  @override
  double get maxZoom => _maxZoom;

  @override
  double get zoom => _zoom;

  @override
  Future<void> setZoom(double level) async {
    final z = level.clamp(1.0, _maxZoom);
    await controller.setZoomLevel(z);
    _zoom = z;
  }

  /// Clockwise rotation that makes this camera's frames upright for the
  /// phone's current orientation (see [frameRotation]). On iOS the plugin's
  /// image stream is already upright; on Android it is in sensor orientation.
  @override
  int get uprightRotation => frameRotation(
        alreadyUpright: Platform.isIOS,
        sensorOrientation: controller.description.sensorOrientation,
        deviceOrientation: switch (controller.value.deviceOrientation) {
          DeviceOrientation.portraitUp => 0,
          DeviceOrientation.landscapeLeft => 90,
          DeviceOrientation.portraitDown => 180,
          DeviceOrientation.landscapeRight => 270,
        },
      );

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

  @override
  Future<void> dispose() async {
    await _frames?.close();
    _frames = null;
    await controller.dispose();
  }
}
