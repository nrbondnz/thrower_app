// Packs a video into a Live test recording (`.tfrm`, see
// lib/camera/frame_pack.dart): JPEG frames at a fixed rate, which the app
// plays in place of the camera.
//
//   dart run tool/pack_recording.dart <video> <out.tfrm> [--ffmpeg <path>] [--fps 15] [--quality 5]
//
// Needs ffmpeg (on the PATH, or give its path). --quality is ffmpeg's JPEG
// q:v (2 best … 31 worst); 5 keeps the 140 px board crops at ~3.7 KB a frame.
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:thrower_app/camera/frame_pack.dart';

Future<void> main(List<String> args) async {
  String option(String name, String fallback) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final positional = [
    for (var i = 0; i < args.length; i++)
      if (args[i].startsWith('--')) ...[] else if (i > 0 && args[i - 1].startsWith('--')) ...[] else args[i],
  ];
  if (positional.length != 2) {
    stderr.writeln('Usage: dart run tool/pack_recording.dart <video> <out.tfrm> [--ffmpeg <path>] [--fps 15] [--quality 5]');
    exit(64);
  }
  final ffmpeg = option('ffmpeg', 'ffmpeg');
  final fps = int.parse(option('fps', '15'));
  final quality = option('quality', '5');

  final temp = await Directory.systemTemp.createTemp('pack_recording');
  try {
    final result = await Process.run(ffmpeg, [
      '-loglevel', 'error', '-i', positional[0], '-vf', 'fps=$fps', '-q:v', quality, '${temp.path}/f%06d.jpg', //
    ]);
    if (result.exitCode != 0) {
      stderr.writeln('ffmpeg failed: ${result.stderr}');
      exit(1);
    }
    final files = temp.listSync().whereType<File>().where((f) => f.path.endsWith('.jpg')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final jpegs = [for (final f in files) f.readAsBytesSync()];
    final first = img.decodeJpg(jpegs.first)!;
    final pack = FramePack.build(width: first.width, height: first.height, fps: fps, jpegs: jpegs);
    File(positional[1])
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(pack);
    stdout.writeln('${positional[1]}: ${jpegs.length} frames, ${first.width} × ${first.height}, $fps fps, '
        '${(pack.length / 1024 / 1024).toStringAsFixed(1)} MB');
  } finally {
    temp.deleteSync(recursive: true);
  }
}
