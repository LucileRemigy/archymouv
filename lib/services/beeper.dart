import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Petits bips générés à la volée (pas de fichier son à fournir).
class Beeper {
  Beeper._();

  static final AudioPlayer _player = AudioPlayer();
  static final Map<String, Uint8List> _cache = {};

  /// Mesure armée (toucher de l'écran) : « c'est lancé ».
  static Future<void> armed() => _play('armed', [(880, 120)]);

  /// Début de l'enregistrement (arc remonté).
  static Future<void> recording() => _play('rec', [(1320, 180)]);

  /// Fin de l'enregistrement.
  static Future<void> done() => _play('done', [(990, 110), (0, 70), (660, 160)]);

  static Future<void> _play(String key, List<(int, int)> notes) async {
    try {
      HapticFeedback.mediumImpact();
      final bytes = _cache[key] ??= _wav(notes);
      await _player.stop();
      await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (e) {
      debugPrint('Bip impossible : $e');
    }
  }

  /// WAV PCM 16 bits mono 22,05 kHz. notes = [(fréquence Hz, durée ms)],
  /// fréquence 0 = silence.
  static Uint8List _wav(List<(int, int)> notes) {
    const rate = 22050;
    final samples = <int>[];
    for (final (f, ms) in notes) {
      final n = rate * ms ~/ 1000;
      for (var i = 0; i < n; i++) {
        final env = min(1.0, min(i, n - i) / (rate * 0.008)); // fondu 8 ms
        final v = f == 0 ? 0.0 : sin(2 * pi * f * i / rate) * 0.6 * env;
        samples.add((v * 32767).round());
      }
    }
    final data = ByteData(44 + samples.length * 2);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + samples.length * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, samples.length * 2, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return data.buffer.asUint8List();
  }
}
