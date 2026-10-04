import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/frame_rate_meter.dart';

void main() {
  test('reports 0 before any frames', () {
    expect(FrameRateMeter().framesPerSecond, 0);
  });

  test('counts 30 frames spread over one second as 30 fps', () {
    final meter = FrameRateMeter();
    for (var i = 0; i < 30; i++) {
      meter.record(Duration(milliseconds: i * 33));
    }
    expect(meter.framesPerSecond, 30);
  });

  test('drops frames older than one second', () {
    final meter = FrameRateMeter()
      ..record(Duration.zero)
      ..record(const Duration(milliseconds: 500))
      ..record(const Duration(milliseconds: 1600));
    expect(meter.framesPerSecond, 1);
  });
}
