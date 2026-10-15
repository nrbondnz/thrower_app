import 'package:audioplayers/audioplayers.dart';

/// A recording's sound track, played alongside its frames (the Quick draw
/// clip's countdown and thuds). Tests replace it.
abstract interface class RecordingSound {
  /// Plays from the start (again, if it was already playing).
  Future<void> playFromStart();

  /// Stops, ready to play from the start.
  Future<void> stop();

  Future<void> dispose();
}

/// A bundled audio asset, played with the `audioplayers` plugin. Loaded once
/// and kept ready ([ReleaseMode.stop]), so a replay starts without reloading.
///
/// It **ducks** other apps' audio (music is turned down while it plays, not
/// stopped) and plays even with the iPhone's silent switch on, so a countdown
/// is heard (Nigel, 2026-10-14). The plugin's default stopped other audio.
class AssetRecordingSound implements RecordingSound {
  AssetRecordingSound(this.asset) {
    _ready = _player
        .setAudioContext(audioContext)
        .then((_) => _player.setReleaseMode(ReleaseMode.stop))
        .then((_) => _player.setSource(AssetSource(_relative(asset))));
  }

  /// Duck others; ignore the silent switch. Built for the platform it runs on
  /// (the plugin leaves out the iOS part elsewhere).
  static AudioContext get audioContext =>
      AudioContextConfig(focus: AudioContextConfigFocus.duckOthers, respectSilence: false).build();

  /// Full asset path, e.g. `assets/live/quickdraw.m4a`.
  final String asset;
  final _player = AudioPlayer();
  late final Future<void> _ready;

  /// [AssetSource] paths are relative to `assets/`.
  static String _relative(String asset) => asset.startsWith('assets/') ? asset.substring('assets/'.length) : asset;

  @override
  Future<void> playFromStart() async {
    await _ready;
    await _player.seek(Duration.zero);
    await _player.resume();
  }

  @override
  Future<void> stop() async {
    await _ready;
    await _player.stop();
  }

  @override
  Future<void> dispose() => _player.dispose();
}
