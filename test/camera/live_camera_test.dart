import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/live_camera.dart';

void main() {
  const cases = <(String, CameraFailure)>[
    ('CameraAccessDenied', CameraFailure.denied),
    ('CameraAccessDeniedWithoutPrompt', CameraFailure.deniedPermanently),
    ('CameraAccessRestricted', CameraFailure.restricted),
    ('SomethingElse', CameraFailure.unknown),
  ];
  for (final (code, expected) in cases) {
    test('camera plugin error $code maps to $expected', () {
      expect(LiveCamera.failureFor(code), expected);
    });
  }
}
