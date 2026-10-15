import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/camera_frame.dart';
import 'package:thrower_app/camera/target_camera.dart';
import 'package:thrower_app/game/find_target.dart';
import 'package:thrower_app/vision/ellipse.dart';
import 'package:thrower_app/vision/locate_in_frame.dart';
import 'package:thrower_app/vision/target_locator.dart';

/// A camera that remembers its zoom; [refuseZoom] makes it throw like a
/// camera that can't.
class ZoomCamera implements TargetCamera {
  ZoomCamera({this.maxZoom = 10, this.refuseZoom = false});

  @override
  final double maxZoom;
  final bool refuseZoom;

  @override
  double zoom = 1;

  final zooms = <double>[];

  @override
  Future<void> setZoom(double level) async {
    if (refuseZoom) throw Exception('zoom not supported');
    zoom = level.clamp(1, maxZoom);
    zooms.add(zoom);
  }

  @override
  int get uprightRotation => 0;

  @override
  int get minChange => 12;

  @override
  Duration get now => Duration.zero;

  @override
  Stream<CameraFrame> frames() => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

/// A board of [radius] at the centre of a 1280 × 720 picture.
FrameLocateResult found(double radius) {
  final outer = Ellipse(cx: 640, cy: 360, semiMajor: radius, semiMinor: radius, angle: 0);
  return FrameLocateResult(
    TargetFound(boundaries: {0.8: outer.scaled(0.8)}, outer: outer, confidence: 0.9, boundaryPoints: const {}),
    1280,
    720,
  );
}

const notFound = FrameLocateResult(TargetNotFound('Rings too unclear'), 1280, 720);

void main() {
  /// A ring finder that gives [atOne] at 1× and [zoomed] when zoomed in, and
  /// records the zoom of each search.
  FrameLocator locator(ZoomCamera camera, List<double> seen, FrameLocateResult atOne, FrameLocateResult zoomed) =>
      (c) async {
        seen.add(camera.zoom);
        return camera.zoom == 1 ? atOne : zoomed;
      };

  test('finds at 1×, zooms in on the board, and keeps the zoomed rings', () async {
    final camera = ZoomCamera(), seen = <double>[];
    final closer = found(252);
    final result = await findTarget(camera, locator(camera, seen, found(50), closer), settle: Duration.zero);
    expect(seen, [1, closeTo(5.04, 1e-9)], reason: 'searched at 1×, then zoomed in');
    expect(result.zoom, closeTo(5.04, 1e-9));
    expect(result.found, same(closer));
    expect(result.offCentre, isFalse);
  });

  test('starts from 1× even when already zoomed (Find again)', () async {
    final camera = ZoomCamera()..zoom = 4;
    final seen = <double>[];
    await findTarget(camera, locator(camera, seen, found(50), found(252)), settle: Duration.zero);
    expect(seen.first, 1);
  });

  test('goes back to 1× and keeps the first rings if the zoomed search fails', () async {
    final camera = ZoomCamera(), seen = <double>[];
    final wide = found(50);
    final result = await findTarget(camera, locator(camera, seen, wide, notFound), settle: Duration.zero);
    expect(result.found, same(wide));
    expect(result.zoom, 1);
    expect(camera.zoom, 1, reason: 'the camera must match the rings kept');
  });

  test('stays at 1× when nothing is found', () async {
    final camera = ZoomCamera(), seen = <double>[];
    final result = await findTarget(camera, locator(camera, seen, notFound, found(252)), settle: Duration.zero);
    expect(seen, [1]);
    expect(result.zoom, 1);
    expect(result.found, same(notFound));
  });

  test("a camera that can't zoom (a recording) searches once, at 1×", () async {
    final camera = ZoomCamera(maxZoom: 1), seen = <double>[];
    final wide = found(50);
    final result = await findTarget(camera, locator(camera, seen, wide, notFound), settle: Duration.zero);
    expect(seen, [1]);
    expect(result.found, same(wide));
    expect(camera.zooms, isEmpty);
  });

  test('a camera that refuses to zoom keeps the 1× rings', () async {
    final camera = ZoomCamera(refuseZoom: true), seen = <double>[];
    final wide = found(50);
    final result = await findTarget(camera, locator(camera, seen, wide, notFound), settle: Duration.zero);
    expect(result.found, same(wide));
    expect(result.zoom, 1);
  });
}
