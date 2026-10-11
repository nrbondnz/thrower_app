import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/target_calibration.dart';
import 'package:thrower_app/vision/zoom_to_fit.dart';

/// A round board of [radius] at ([cx], [cy]) in a 1280 × 720 picture.
TargetCalibration board(double cx, double cy, double radius) => TargetCalibration(
      imageWidth: 1280,
      imageHeight: 720,
      boundaries: const {},
      outer: Ellipse(cx: cx, cy: cy, semiMajor: radius, semiMinor: radius, angle: 0),
    );

void main() {
  test('a small centred board is zoomed until it fills 70% of the short side', () {
    final plan = zoomToFit(board(640, 360, 50), maxZoom: 10);
    expect(plan.zoom, closeTo(0.7 * 720 / 100, 1e-9)); // 5.04×
    expect(plan.offCentre, isFalse);
  });

  test("no further than the camera's maximum zoom", () {
    final plan = zoomToFit(board(640, 360, 50), maxZoom: 3);
    expect(plan.zoom, 3);
    expect(plan.offCentre, isFalse);
  });

  test('an off-centre board is zoomed only as far as keeps it (and a margin) in the picture', () {
    // Its far side plus the 0.3 × radius margin is 425 px from the centre;
    // half the picture's width is 640 px.
    final plan = zoomToFit(board(1000, 360, 50), maxZoom: 10);
    expect(plan.zoom, closeTo(640 / 425, 1e-9));
    expect(plan.offCentre, isTrue, reason: 'the user should be told to centre the board');
  });

  test('a board that already fills the picture is not zoomed', () {
    final plan = zoomToFit(board(640, 360, 300), maxZoom: 10);
    expect(plan.zoom, 1);
    expect(plan.offCentre, isFalse);
  });

  test("a gain under 1.2× isn't worth it, but off-centre is still reported", () {
    final plan = zoomToFit(board(1200, 360, 50), maxZoom: 10);
    expect(plan.zoom, 1);
    expect(plan.offCentre, isTrue);
  });

  test("a camera that can't zoom gives 1×, and no tip", () {
    final plan = zoomToFit(board(1000, 360, 50), maxZoom: 1);
    expect(plan.zoom, 1);
    expect(plan.offCentre, isFalse);
  });
}
