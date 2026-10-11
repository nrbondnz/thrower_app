import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../camera/recorded_camera.dart';

/// The Live test recording's current frame, scaled to fit, with [child] drawn
/// exactly over it (like `CameraPreview`'s child), and the playback time.
class RecordedPreview extends StatefulWidget {
  const RecordedPreview({super.key, required this.camera, this.child});

  final RecordedCamera camera;
  final Widget? child;

  @override
  State<RecordedPreview> createState() => _RecordedPreviewState();
}

class _RecordedPreviewState extends State<RecordedPreview> {
  ui.Image? _image;
  int? _shownIndex;

  @override
  void initState() {
    super.initState();
    widget.camera.current.addListener(_update);
    _update();
  }

  @override
  void didUpdateWidget(RecordedPreview old) {
    super.didUpdateWidget(old);
    if (old.camera != widget.camera) {
      old.camera.current.removeListener(_update);
      widget.camera.current.addListener(_update);
      _update();
    }
  }

  @override
  void dispose() {
    widget.camera.current.removeListener(_update);
    _image?.dispose();
    super.dispose();
  }

  void _update() {
    final frame = widget.camera.current.value;
    if (frame == null || frame.index == _shownIndex) return;
    _shownIndex = frame.index;
    ui.decodeImageFromPixels(frame.rgba, frame.width, frame.height, ui.PixelFormat.rgba8888, (image) {
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.camera.pack;
    return AspectRatio(
      aspectRatio: pack.width / pack.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RawImage(image: _image, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
          ?widget.child,
          Positioned(
            right: 8,
            bottom: 8,
            child: ValueListenableBuilder(
              valueListenable: widget.camera.position,
              builder: (context, position, _) => Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '${widget.camera.recording.name} · ${clockText(position)} / ${clockText(widget.camera.duration)}',
                  key: const Key('recordingTime'),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "1:05".
String clockText(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
