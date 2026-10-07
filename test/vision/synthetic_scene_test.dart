import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/vision/synthetic_scene.dart';

void main() {
  test('the board centre projects to the image centre (camera aims at it)', () {
    final scene = SyntheticScene(width: 400, height: 300);
    final p = scene.project(const Vec3(0, 0, 0));
    expect(p.x, closeTo(200, 1e-6));
    expect(p.y, closeTo(150, 1e-6));
  });

  test('from the right, the board is squashed horizontally, not vertically', () {
    final scene = SyntheticScene(width: 400, height: 300, cameraPosition: const Vec3(2, 0, 2));
    final left = scene.project(const Vec3(-0.2, 0, 0)), right = scene.project(const Vec3(0.2, 0, 0));
    final top = scene.project(const Vec3(0, 0.2, 0)), bottom = scene.project(const Vec3(0, -0.2, 0));
    final across = right.x - left.x, down = bottom.y - top.y;
    // 45° off straight-on: horizontal extent ≈ cos 45° of vertical.
    expect(across / down, closeTo(0.707, 0.05));
  });

  test('knife answers give each entry point and its score', () {
    final scene = SyntheticScene(
      width: 160,
      height: 120,
      supersample: 1,
      knives: const [
        StuckKnife(u: 0.1, v: 0.05, pitchDegrees: 15),
        StuckKnife(u: -0.5, v: -0.4, yawDegrees: 10),
        StuckKnife(u: 0.95, v: 0.2),
        StuckKnife(u: 1.1, v: 0),
      ],
    );
    final rendered = scene.render();
    // Radii 0.11, 0.64, 0.97, 1.1.
    expect([for (final k in rendered.knives) k.score], [5, 2, 1, 0]);
    final entry = rendered.knives.first.entryPixel;
    final projected = scene.project(Vec3(0.1 * scene.targetRadius, 0.05 * scene.targetRadius, 0));
    expect(entry.x, closeTo(projected.x, 1e-9));
    expect(entry.y, closeTo(projected.y, 1e-9));
  });

  test('the bull is painted colour A and the next ring colour B', () {
    final scene = SyntheticScene(width: 400, height: 300, supersample: 1, cameraPosition: const Vec3(0, 0, 2));
    final img = scene.render().image;
    // Straight on: the image centre is the bull.
    expect(img.red(200, 150), greaterThan(img.green(200, 150) * 2));
    // Halfway between the 0.2 and 0.4 edges is wood (B): green is high too.
    final ring = scene.project(Vec3(0.3 * scene.targetRadius, 0, 0));
    final x = ring.x.round(), y = ring.y.round();
    expect(img.green(x, y), greaterThan(120));
  });
}
