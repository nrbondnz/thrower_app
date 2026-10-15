import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrower_app/camera/recording_sound.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test("ducks other apps' audio on Android rather than taking it over", () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AssetRecordingSound.audioContext.android.audioFocus, AndroidAudioFocus.gainTransientMayDuck);
  });

  test('ducks other audio on iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AssetRecordingSound.audioContext.iOS.options, {AVAudioSessionOptions.duckOthers});
  });

  test('plays with the iPhone silent switch on (playback, not ambient)', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AssetRecordingSound.audioContext.iOS.category, AVAudioSessionCategory.playback);
  });
}
