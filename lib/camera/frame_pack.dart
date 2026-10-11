import 'dart:typed_data';

/// A recording packed as JPEG frames at a fixed frame rate, in one file
/// (`.tfrm`), made by `tool/pack_recording.dart`. Pure Dart, so the app
/// decodes it without a video plugin.
///
/// Layout (little-endian): `TFRM`, u16 version (1), u16 width, u16 height,
/// u16 frames per second, u32 frame count, then u32 offsets × (count + 1)
/// into the JPEG data that follows (the last is its length).
class FramePack {
  FramePack._(this.width, this.height, this.fps, this._offsets, this._data);

  static const _magic = [0x54, 0x46, 0x52, 0x4d]; // "TFRM"
  static const _version = 1;
  static const _headerLength = 16;

  final int width;
  final int height;
  final int fps;
  final Uint32List _offsets;
  final Uint8List _data;

  int get frameCount => _offsets.length - 1;

  Duration get duration => Duration(microseconds: (frameCount * 1000000 / fps).round());

  /// The JPEG bytes of frame [index] (a view into the pack, not a copy).
  Uint8List jpeg(int index) =>
      Uint8List.sublistView(_data, _offsets[index], _offsets[index + 1]);

  static FramePack parse(Uint8List bytes) {
    if (bytes.length < _headerLength) throw const FormatException('Not a frame pack: too short');
    for (var i = 0; i < 4; i++) {
      if (bytes[i] != _magic[i]) throw const FormatException('Not a frame pack: wrong signature');
    }
    final header = ByteData.sublistView(bytes);
    final version = header.getUint16(4, Endian.little);
    if (version != _version) throw FormatException('Unsupported frame pack version $version');
    final width = header.getUint16(6, Endian.little);
    final height = header.getUint16(8, Endian.little);
    final fps = header.getUint16(10, Endian.little);
    final count = header.getUint32(12, Endian.little);
    final dataStart = _headerLength + (count + 1) * 4;
    if (fps == 0 || count == 0 || bytes.length < dataStart) throw const FormatException('Frame pack header is invalid');
    final offsets = Uint32List(count + 1);
    for (var i = 0; i <= count; i++) {
      offsets[i] = header.getUint32(_headerLength + i * 4, Endian.little);
    }
    final data = Uint8List.sublistView(bytes, dataStart);
    if (offsets.last != data.length) throw const FormatException('Frame pack is truncated');
    return FramePack._(width, height, fps, offsets, data);
  }

  /// Packs [jpegs] (one per frame, all [width] × [height]) at [fps].
  static Uint8List build({required int width, required int height, required int fps, required List<Uint8List> jpegs}) {
    final dataLength = jpegs.fold<int>(0, (sum, j) => sum + j.length);
    final out = BytesBuilder(copy: false);
    final header = ByteData(_headerLength + (jpegs.length + 1) * 4);
    for (var i = 0; i < 4; i++) {
      header.setUint8(i, _magic[i]);
    }
    header
      ..setUint16(4, _version, Endian.little)
      ..setUint16(6, width, Endian.little)
      ..setUint16(8, height, Endian.little)
      ..setUint16(10, fps, Endian.little)
      ..setUint32(12, jpegs.length, Endian.little);
    var offset = 0;
    for (var i = 0; i < jpegs.length; i++) {
      header.setUint32(_headerLength + i * 4, offset, Endian.little);
      offset += jpegs[i].length;
    }
    header.setUint32(_headerLength + jpegs.length * 4, dataLength, Endian.little);
    out.add(header.buffer.asUint8List());
    for (final j in jpegs) {
      out.add(j);
    }
    return out.toBytes();
  }
}
