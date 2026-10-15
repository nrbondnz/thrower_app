import 'package:audioplayers/audioplayers.dart';

import '../camera/recording_sound.dart';

/// Quick draw's start signal and result chime. Tests replace it.
abstract interface class SignalSounds {
  /// One of the 5 countdown beeps.
  Future<void> beep();

  /// The long "go" beep.
  Future<void> go();

  /// The result is in.
  Future<void> result();

  Future<void> dispose();
}

/// The bundled sounds (`assets/sounds/`, made by `tool/make_signal_sounds.dart`),
/// each on its own player, loaded once in low-latency mode (short sounds,
/// started as soon as asked: the "go" beep is when the throwers go). They
/// duck other apps' audio and play with the silent switch on, like the Live
/// test's sound (`AssetRecordingSound.audioContext`).
class AssetSignalSounds implements SignalSounds {
  AssetSignalSounds() {
    _ready = Future.wait([
      for (final (player, file) in [(_beep, 'beep.wav'), (_go, 'go.wav'), (_result, 'result.wav')])
        player
            .setAudioContext(AssetRecordingSound.audioContext)
            .then((_) => player.setPlayerMode(PlayerMode.lowLatency))
            .then((_) => player.setReleaseMode(ReleaseMode.stop))
            .then((_) => player.setSource(AssetSource('sounds/$file'))),
    ]);
  }

  final _beep = AudioPlayer();
  final _go = AudioPlayer();
  final _result = AudioPlayer();
  late final Future<void> _ready;

  Future<void> _play(AudioPlayer player) async {
    await _ready;
    await player.stop();
    await player.resume();
  }

  @override
  Future<void> beep() => _play(_beep);

  @override
  Future<void> go() => _play(_go);

  @override
  Future<void> result() => _play(_result);

  @override
  Future<void> dispose() async {
    for (final p in [_beep, _go, _result]) {
      await p.dispose();
    }
  }
}
