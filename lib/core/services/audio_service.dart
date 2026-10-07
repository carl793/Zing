import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide audio settings and playback.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const _bgmAsset =
      'audio/591777__bloodpixelhero__atmospheric-loop-25 (1).mp3';
  static const _keyBgm = 'pref_bgm';
  static const _keySfx = 'pref_sfx';

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _bgmEnabled = false;
  bool _sfxEnabled = true;
  bool _bgmPlaying = false;

  bool get bgmEnabled => _bgmEnabled;
  bool get sfxEnabled => _sfxEnabled;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _bgmEnabled = prefs.getBool(_keyBgm) ?? false;
    _sfxEnabled = prefs.getBool(_keySfx) ?? true;
    await _sfxPlayer.setAudioContext(
      AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build(),
    );
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(0.35);
    if (_bgmEnabled) await _startBgm();
  }

  Future<void> setBgmEnabled(bool enabled) async {
    _bgmEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBgm, enabled);
    if (enabled) {
      await _startBgm();
    } else {
      await _bgmPlayer.stop();
      _bgmPlaying = false;
    }
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySfx, enabled);
  }

  Future<void> _startBgm() async {
    if (_bgmPlaying) return;
    try {
      await _bgmPlayer.play(AssetSource(_bgmAsset));
      _bgmPlaying = true;
    } catch (_) {
      _bgmPlaying = false;
      // A playback error must not interrupt navigation or settings changes.
    }
  }

  Future<void> playSfx(AppSfx sfx) async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(BytesSource(_makeTone(sfx.frequency)));
    } catch (_) {
      // Sound effects must never interrupt an app action.
    }
  }

  Uint8List _makeTone(double frequency) {
    const sampleRate = 22050;
    const sampleCount = 1102;
    const dataSize = sampleCount * 2;
    final bytes = ByteData(44 + dataSize);
    void text(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    text(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    text(8, 'WAVE');
    text(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    text(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < sampleCount; i++) {
      final fade = math.min(i / 100, (sampleCount - i) / 150).clamp(0.0, 1.0);
      final wave = math.sin(2 * math.pi * frequency * i / sampleRate);
      bytes.setInt16(44 + i * 2, (wave * fade * 7000).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  Future<void> dispose() async {
    await _bgmPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}

enum AppSfx {
  tap(880),
  save(1175),
  unlock(1568);

  final double frequency;
  const AppSfx(this.frequency);
}
