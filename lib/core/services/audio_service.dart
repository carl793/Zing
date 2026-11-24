import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
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
  bool _bgmLoaded = false;
  bool _bgmAudible = false;
  bool _inForeground = true;

  /// How many things (a recording, a playing voice note) need silence.
  int _musicHolds = 0;

  /// Generated once each; a tap must not recompute its own sound.
  final Map<AppSfx, Uint8List> _tones = {};

  bool get bgmEnabled => _bgmEnabled;
  bool get sfxEnabled => _sfxEnabled;

  /// Never throws: the app must start even if audio doesn't.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _bgmEnabled = prefs.getBool(_keyBgm) ?? false;
      _sfxEnabled = prefs.getBool(_keySfx) ?? true;
      AppLifecycleListener(
        onHide: () => _setForeground(false),
        onShow: () => _setForeground(true),
      );
      await _sfxPlayer.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.35);
      await _updateBgm();
    } catch (e) {
      debugPrint('Audio setup failed: $e');
    }
  }

  Future<void> setBgmEnabled(bool enabled) async {
    _bgmEnabled = enabled;
    await _updateBgm();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBgm, enabled);
  }

  /// Silences the music until a matching [releaseMusic].
  void holdMusic() {
    _musicHolds++;
    _updateBgm();
  }

  void releaseMusic() {
    if (_musicHolds > 0) _musicHolds--;
    _updateBgm();
  }

  void _setForeground(bool foreground) {
    _inForeground = foreground;
    _updateBgm();
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySfx, enabled);
  }

  /// Plays or pauses the music to match the current settings.
  Future<void> _updateBgm() =>
      // One at a time, so a quick off/on can't overlap and end up reversed.
      _bgmQueue = _bgmQueue.then((_) => _applyBgm());

  Future<void> _bgmQueue = Future.value();

  Future<void> _applyBgm() async {
    final wanted = _bgmEnabled && _inForeground && _musicHolds == 0;
    if (wanted == _bgmAudible) return;
    _bgmAudible = wanted;
    try {
      if (!wanted) {
        await _bgmPlayer.pause();
      } else if (_bgmLoaded) {
        await _bgmPlayer.resume();
      } else {
        await _bgmPlayer.play(AssetSource(_bgmAsset));
        _bgmLoaded = true;
      }
    } catch (e) {
      // A playback error must not interrupt anything else.
      _bgmAudible = false;
      debugPrint('Background music failed: $e');
    }
  }

  Future<void> playSfx(AppSfx sfx) async {
    if (!_sfxEnabled) return;
    try {
      final tone = _tones[sfx] ??= _makeTone(sfx.frequency);
      await _sfxPlayer.stop();
      await _sfxPlayer.play(BytesSource(tone));
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
