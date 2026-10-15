import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/camera_frame.dart';
import 'package:thrower_app/camera/frame_pack.dart';
import 'package:thrower_app/camera/recorded_camera.dart';
import 'package:thrower_app/vision/decode_image.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/rgb_image.dart';
import 'package:thrower_app/vision/tapped_target_locator.dart';
import 'package:thrower_app/vision/target_locator.dart';

const boundaryRadii = [0.2, 0.4, 0.6, 0.8];

/// Where the two boards are in the Quick draw clip (720 × 1280): the Live test
/// crops' measured centres and ring-2 edge (`live_recording_locate_test.dart`),
/// moved from their crops in the original, (118, 535) and (723, 549), and
/// scaled by 2/3 from 1080 × 1920.
const player1Board = (182.5, 463.4, 49.3);
const player2Board = (592.7, 471.7, 49.3);

/// Null if [result] is a board at [expected] (centre, and the 0.8 boundary's
/// mean radius) within [tolerance] px, otherwise what's wrong. 3 px is about
/// 6% of that radius.
String? mismatch(TargetLocateResult result, (double, double, double) expected, {double tolerance = 3}) {
  if (result is! TargetFound) return 'not found: ${(result as TargetNotFound).reason}';
  final e = result.boundaries[0.8]!;
  final (cx, cy, r) = expected;
  final off = math.sqrt(math.pow(e.cx - cx, 2) + math.pow(e.cy - cy, 2));
  final radius = (e.semiMajor + e.semiMinor) / 2;
  if (off > tolerance || (radius - r).abs() > tolerance) {
    return 'centre (${e.cx.toStringAsFixed(1)}, ${e.cy.toStringAsFixed(1)}) is ${off.toStringAsFixed(1)} px from '
        '($cx, $cy); radius ${radius.toStringAsFixed(1)} (expected $r)';
  }
  return null;
}

Point2 centreOf((double, double, double) board, {double dx = 0, double dy = 0}) => Point2(board.$1 + dx, board.$2 + dy);

void main() {
  late FramePack pack;
  late RgbImage first;

  setUpAll(() {
    pack = FramePack.parse(File(quickDrawRecording.asset).readAsBytesSync());
    first = decodeToRgb(pack.jpeg(0))!;
  });

  // Taps on each board's centre, on still frames before the throws (every
  // 30th, 0.5 s apart): the boards are found where measured. Probed on 16
  // frames (2026-10-14): 32 of 32 boards found at 3× enlargement.
  for (final i in [0, 30, 60, 90, 120, 150]) {
    test('frame $i: a tap on each centre finds that board where measured', () {
      final frame = decodeToRgb(pack.jpeg(i))!;
      expect(mismatch(locateTargetAt(frame, centreOf(player1Board), boundaryRadii), player1Board), isNull, reason: 'Player 1');
      expect(mismatch(locateTargetAt(frame, centreOf(player2Board), boundaryRadii), player2Board), isNull, reason: 'Player 2');
    });
  }

  test('a tap 10 px off the centre still finds the board (snapped to the ring it lands in)', () {
    expect(mismatch(locateTargetAt(first, centreOf(player1Board, dx: 10), boundaryRadii), player1Board), isNull);
    expect(mismatch(locateTargetAt(first, centreOf(player2Board, dx: 10), boundaryRadii), player2Board), isNull);
  });

  test('a tap on the grass, away from both boards, finds nothing', () {
    expect(locateTargetAt(first, const Point2(360, 1100), boundaryRadii), isA<TargetNotFound>());
  });

  test("on a camera frame, each tap is found in tap order, in the upright picture's size", () {
    final bgra = Uint8List(first.width * first.height * 4);
    for (var i = 0; i < first.width * first.height; i++) {
      bgra[i * 4] = first.pixels[i * 3 + 2];
      bgra[i * 4 + 1] = first.pixels[i * 3 + 1];
      bgra[i * 4 + 2] = first.pixels[i * 3];
      bgra[i * 4 + 3] = 255;
    }
    final frame = CameraFrame(
      width: first.width,
      height: first.height,
      format: FrameFormat.bgra8888,
      planes: [FramePlane(bytes: bgra, bytesPerRow: first.width * 4, bytesPerPixel: 4)],
      timestamp: Duration.zero,
    );
    // Taps as fractions of the picture (720 × 1280), as the screen sends them.
    Point2 fraction(Point2 p) => Point2(p.x / 720, p.y / 1280);
    final result = locateTappedInFrame(
        (frame, 0, boundaryRadii, [fraction(centreOf(player2Board)), fraction(centreOf(player1Board))]));
    expect((result.imageWidth, result.imageHeight), (720, 1280));
    expect(mismatch(result.boards[0], player2Board), isNull);
    expect(mismatch(result.boards[1], player1Board), isNull);
  });

  test('a sideways frame (as an Android camera sends it) is turned upright first; taps are fractions of the upright picture', () {
    // The first frame turned a quarter-turn anticlockwise (1280 × 720), so it
    // needs rotating 90° clockwise to be upright, as frameToRgb does.
    const w = 720, h = 1280;
    final bgra = Uint8List(w * h * 4);
    for (var uy = 0; uy < h; uy++) {
      for (var ux = 0; ux < w; ux++) {
        // Upright (ux, uy) is sideways (uy, w - 1 - ux) in a frame h wide.
        final i = ((w - 1 - ux) * h + uy) * 4, j = (uy * w + ux) * 3;
        bgra[i] = first.pixels[j + 2];
        bgra[i + 1] = first.pixels[j + 1];
        bgra[i + 2] = first.pixels[j];
        bgra[i + 3] = 255;
      }
    }
    final frame = CameraFrame(
      width: h,
      height: w,
      format: FrameFormat.bgra8888,
      planes: [FramePlane(bytes: bgra, bytesPerRow: h * 4, bytesPerPixel: 4)],
      timestamp: Duration.zero,
    );
    Point2 fraction(Point2 p) => Point2(p.x / w, p.y / h);
    final result = locateTappedInFrame((frame, 90, boundaryRadii, [fraction(centreOf(player1Board))]));
    expect((result.imageWidth, result.imageHeight), (w, h));
    expect(mismatch(result.boards.single, player1Board), isNull);
  });
}
