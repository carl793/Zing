import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's sound effects (`assets/audio/sfx`, made by tool/make_sfx.py).
enum AppSfx {
  tap('tap'),
  tick('tick'),
  toggleOn('toggle_on'),
  toggleOff('toggle_off'),
  open('open'),
  close('close'),
  hop('hop'),
  save('save'),
  seal('seal'),
  unlock('unlock'),
  error('error');

  const AppSfx(this.file);
  final String file;
}

/// App-wide music, sound effects and vibration, with the player's settings.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const _bgmAsset =
      'audio/591777__bloodpixelhero__atmospheric-loop-25 (1).mp3';
  static const _keyBgm = 'pref_bgm';
  static const _keySfx = 'pref_sfx';
  static const _keyHaptics = 'pref_haptics';
  static const _sfxVolume = 0.6;

  bool _bgmEnabled = false;
  bool _sfxEnabled = true;
  bool _hapticsEnabled = true;

  /// False until [init] has run: no player exists before then.
  bool _ready = false;
  late final AudioPlayer _bgmPlayer;
  bool _bgmLoaded = false;
  bool _bgmAudible = false;
  bool _inForeground = true;

  /// How many things (a recording, a playing voice note) need silence.
  int _musicHolds = 0;

  bool get bgmEnabled => _bgmEnabled;
  bool get sfxEnabled => _sfxEnabled;
  bool get hapticsEnabled => _hapticsEnabled;

  /// Never throws: the app must start even if audio doesn't.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _bgmEnabled = prefs.getBool(_keyBgm) ?? false;
      _sfxEnabled = prefs.getBool(_keySfx) ?? true;
      _hapticsEnabled = prefs.getBool(_keyHaptics) ?? true;
      AppLifecycleListener(
        onHide: () => _setForeground(false),
        onShow: () => _setForeground(true),
      );
      _bgmPlayer = AudioPlayer();
      _ready = true;
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(0.35);
      await _updateBgm();
      // The click is needed first, and at once.
      await _playerFor(AppSfx.tap);
    } catch (e) {
      debugPrint('Audio setup failed: $e');
    }
  }

  // ── Music ──────────────────────────────────────────────────────────────

  Future<void> setBgmEnabled(bool enabled) async {
    _bgmEnabled = enabled;
    await _updateBgm();
    await _store(_keyBgm, enabled);
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

  /// Plays or pauses the music to match the current settings.
  Future<void> _updateBgm() =>
      // One at a time, so a quick off/on can't overlap and end up reversed.
      _bgmQueue = _bgmQueue.then((_) => _applyBgm());

  Future<void> _bgmQueue = Future.value();

  Future<void> _applyBgm() async {
    if (!_ready) return;
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

  // ── Sound effects ──────────────────────────────────────────────────────

  /// One loaded player per effect, so a click sounds the moment it's pressed
  /// instead of preparing a player first.
  final Map<AppSfx, Future<AudioPlayer>> _sfxPlayers = {};

  Future<AudioPlayer> _playerFor(AppSfx sfx) =>
      _sfxPlayers[sfx] ??= _createPlayer(sfx);

  Future<AudioPlayer> _createPlayer(AppSfx sfx) async {
    final player = AudioPlayer();
    await player.setPlayerMode(PlayerMode.lowLatency);
    // Never pauses the player's own music app.
    await player.setAudioContext(
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
    );
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setVolume(_sfxVolume);
    await player.setSource(AssetSource('audio/sfx/${sfx.file}.wav'));
    return player;
  }

  Future<void> playSfx(AppSfx sfx) async {
    if (!_ready || !_sfxEnabled || !_inForeground) return;
    try {
      final player = await _playerFor(sfx);
      await player.stop();
      await player.resume();
    } catch (e) {
      // Sound effects must never interrupt an app action.
      _sfxPlayers.remove(sfx);
      debugPrint('Sound effect failed: $e');
    }
  }

  Future<void> setSfxEnabled(bool enabled) {
    _sfxEnabled = enabled;
    return _store(_keySfx, enabled);
  }

  // ── Vibration ──────────────────────────────────────────────────────────

  Future<void> setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
    return _store(_keyHaptics, enabled);
  }

  /// The small knock of a key being pressed.
  void knock({bool strong = false}) {
    if (!_hapticsEnabled) return;
    strong ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
  }

  Future<void> _store(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Saving $key failed: $e');
    }
  }
}
