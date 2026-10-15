// Writes Quick draw's start-signal sounds as small WAV files (mono, 16-bit,
// 22.05 kHz) into assets/sounds/:
//
//   beep.wav    each of the 5 countdown beeps: 1 kHz, 0.2 s
//   go.wav      the "go" beep: 1.5 kHz, 0.8 s (longer and higher, so it can't
//               be taken for a countdown beep)
//   result.wav  the result is in: two notes, 660 then 990 Hz, 0.2 s each
//
//   dart run tool/make_signal_sounds.dart
//
// Each tone fades in and out over 5 ms so it doesn't click.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const rate = 22050;

/// [seconds] of a [hz] sine at [volume] (0–1), with 5 ms fades.
List<double> tone(double hz, double seconds, {double volume = 0.8}) {
  final n = (rate * seconds).round();
  final fade = (rate * 0.005).round();
  return [
    for (var i = 0; i < n; i++)
      volume * math.sin(2 * math.pi * hz * i / rate) * math.min(1, math.min(i, n - 1 - i) / fade),
  ];
}

Uint8List wav(List<double> samples) {
  final data = ByteData(44 + samples.length * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little) // PCM header size
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 2, Endian.little) // bytes a second
    ..setUint16(32, 2, Endian.little) // bytes a sample
    ..setUint16(34, 16, Endian.little); // bits a sample
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  final out = Directory('assets/sounds')..createSync(recursive: true);
  final sounds = {
    'beep.wav': tone(1000, 0.2),
    'go.wav': tone(1500, 0.8),
    'result.wav': [...tone(660, 0.2), ...tone(990, 0.2)],
  };
  for (final MapEntry(key: name, value: samples) in sounds.entries) {
    final bytes = wav(samples);
    File('${out.path}/$name').writeAsBytesSync(bytes);
    stdout.writeln('${out.path}/$name: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
  }
}
