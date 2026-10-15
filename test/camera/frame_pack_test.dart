import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:thrower_app/camera/frame_pack.dart';
import 'package:thrower_app/camera/recorded_camera.dart';

void main() {
  group('FramePack', () {
    test('round-trips frames, size and rate', () {
      final jpegs = [
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList([4, 5]),
        Uint8List.fromList([6, 7, 8, 9]),
      ];
      final pack = FramePack.parse(FramePack.build(width: 140, height: 120, fps: 15, jpegs: jpegs));
      expect((pack.width, pack.height, pack.fps, pack.frameCount), (140, 120, 15, 3));
      expect([for (var i = 0; i < 3; i++) pack.jpeg(i)], jpegs);
      expect(pack.duration, const Duration(milliseconds: 200));
    });

    test('rejects a file that is not a frame pack', () {
      expect(() => FramePack.parse(Uint8List.fromList(List.filled(40, 0))), throwsFormatException);
    });

    test('rejects a truncated pack', () {
      final bytes = FramePack.build(width: 2, height: 2, fps: 1, jpegs: [Uint8List.fromList([1, 2, 3])]);
      expect(() => FramePack.parse(Uint8List.sublistView(bytes, 0, bytes.length - 1)), throwsFormatException);
    });
  });

  group('the bundled Live test recordings', () {
    for (final recording in liveTestRecordings) {
      test('${recording.name}: 3 min 10 s of 322 × 322 frames (cut from the original video) at 15 fps, first frame decodes', () {
        final pack = FramePack.parse(File(recording.asset).readAsBytesSync());
        expect((pack.width, pack.height, pack.fps), (322, 322, 15));
        expect(pack.frameCount, 2848);
        final first = img.decodeJpg(pack.jpeg(0))!;
        expect((first.width, first.height), (322, 322));
      });
    }

    test('Quick draw: 7.5 s of full 720 × 1280 frames at 60 fps (both boards), first frame decodes', () {
      final pack = FramePack.parse(File(quickDrawRecording.asset).readAsBytesSync());
      expect((pack.width, pack.height, pack.fps), (720, 1280, 60));
      expect(pack.frameCount, 449);
      final first = img.decodeJpg(pack.jpeg(0))!;
      expect((first.width, first.height), (720, 1280));
    });

    test('Quick draw has its sound track bundled', () {
      expect(File(quickDrawRecording.audio!).lengthSync(), greaterThan(50000));
    });
  });
}
