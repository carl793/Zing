import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../../../core/widgets/pixel_toast.dart';

/// Plays a chest's voice note. The music steps aside while it does.
class VoicePlayer extends StatefulWidget {
  final String url;
  const VoicePlayer({super.key, required this.url});

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  /// Created on the first press, so opening a chest costs nothing.
  AudioPlayer? _player;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;
  bool _holdingMusic = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: () {
      if (_state == PlayerState.playing) _player?.pause();
    });
  }

  @override
  void dispose() {
    _holdMusic(false);
    _lifecycle.dispose();
    _player?.dispose();
    super.dispose();
  }

  void _holdMusic(bool hold) {
    if (hold == _holdingMusic) return;
    _holdingMusic = hold;
    hold
        ? AudioService.instance.holdMusic()
        : AudioService.instance.releaseMusic();
  }

  AudioPlayer _create() {
    final player = AudioPlayer();
    player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      _holdMusic(s == PlayerState.playing);
      setState(() {
        _state = s;
        if (s == PlayerState.completed) _position = Duration.zero;
      });
    });
    player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    return player;
  }

  Future<void> _toggle() async {
    final player = _player ??= _create();
    try {
      if (_state == PlayerState.playing) {
        await player.pause();
      } else if (_state == PlayerState.paused) {
        await player.resume();
      } else {
        setState(() => _loading = true);
        await player
            .play(UrlSource(widget.url))
            .timeout(const Duration(seconds: 20));
      }
    } catch (e) {
      debugPrint('Voice note playback failed: $e');
      if (!mounted) return;
      showPixelToast(
        context,
        "COULDN'T PLAY THE VOICE NOTE. CHECK YOUR INTERNET.",
        color: AppColors.coral,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final playing = _state == PlayerState.playing;
    final total = _duration.inMilliseconds;

    return PixelWell(
      child: Row(
        children: [
          PixelIconButton(
            icon: playing ? PixelIcons.pause : PixelIcons.play,
            label: playing ? 'Pause' : 'Play',
            tone: PixelTone.yellow,
            size: 48,
            onPressed: _loading ? null : _toggle,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: PixelProgressBar(
              value: total > 0 ? _position.inMilliseconds / total : 0,
              tone: PixelTone.cyan,
              blocks: 12,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            total == 0
                ? '--:--'
                : _clock(playing || _position > Duration.zero
                    ? _duration - _position
                    : _duration),
            style: AppTextStyles.button.copyWith(color: AppColors.cyan),
          ),
        ],
      ),
    );
  }
}
