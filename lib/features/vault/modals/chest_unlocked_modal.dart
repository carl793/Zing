import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_error_box.dart';
import '../../../core/widgets/pixel_snack_bar.dart';
import '../../../core/widgets/remote_photo.dart';
import 'photo_lightbox_screen.dart';

class ChestUnlockedModal extends StatefulWidget {
  final CapsuleModel capsule;

  /// Reads what is inside, which the server only allows once it's open.
  final Future<CapsuleContent> Function() loadContent;

  const ChestUnlockedModal({
    super.key,
    required this.capsule,
    required this.loadContent,
  });

  @override
  State<ChestUnlockedModal> createState() => _ChestUnlockedModalState();
}

class _ChestUnlockedModalState extends State<ChestUnlockedModal> {
  final _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _load();
    _lifecycle = AppLifecycleListener(onHide: () {
      if (_playerState == PlayerState.playing) _player.pause();
    });
    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      // The music steps aside for the voice note.
      _holdMusic(s == PlayerState.playing);
      setState(() {
        _playerState = s;
        if (s == PlayerState.completed) _position = Duration.zero;
      });
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  CapsuleContent? _content;
  String? _loadError;

  Future<void> _load() async {
    CapsuleContent? content;
    String? error;
    try {
      content = await widget.loadContent();
    } on FirebaseException catch (e) {
      debugPrint('Opening the chest failed: $e');
      error = e.code == 'permission-denied'
          ? "THIS CHEST ISN'T READY YET. TRY AGAIN IN A MOMENT."
          : "COULDN'T OPEN THE CHEST. CHECK YOUR INTERNET.";
    } catch (e) {
      debugPrint('Opening the chest failed: $e');
      error = "COULDN'T OPEN THE CHEST. CHECK YOUR INTERNET.";
    }
    if (!mounted) return;
    setState(() {
      _content = content;
      _loadError = error;
    });
  }

  void _retry() {
    setState(() => _loadError = null);
    _load();
  }

  bool _holdingMusic = false;

  void _holdMusic(bool hold) {
    if (hold == _holdingMusic) return;
    _holdingMusic = hold;
    hold
        ? AudioService.instance.holdMusic()
        : AudioService.instance.releaseMusic();
  }

  @override
  void dispose() {
    _holdMusic(false);
    _lifecycle.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final url = _content?.voiceNoteUrl;
    if (url == null) return;

    try {
      if (_playerState == PlayerState.playing) {
        await _player.pause();
      } else if (_playerState == PlayerState.paused) {
        await _player.resume();
      } else {
        await _player
            .play(UrlSource(url))
            .timeout(const Duration(seconds: 20));
      }
    } catch (e) {
      debugPrint('Voice note playback failed: $e');
      if (!mounted) return;
      showPixelSnackBar(
        context,
        "COULDN'T PLAY THE VOICE NOTE. CHECK YOUR INTERNET.",
        color: AppColors.coral,
      );
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '---';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDatetime(DateTime? dt) {
    if (dt == null) return '---';
    final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${_formatDate(dt)} @ $h12:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final capsule = widget.capsule;
    final content = _content;
    final photoUrl = content?.photoUrl;
    final hasVoice = content?.voiceNoteUrl != null;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'TREASURE\nUNLOCKED!',
                      style: AppTextStyles.header.copyWith(
                        color: AppColors.yellow,
                        fontSize: 18,
                        height: 1.5,
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _XBtn(),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Chest name
              Text('CHEST NAME', style: AppTextStyles.label),
              const SizedBox(height: 6),
              _insetBox(
                child: Text(
                  capsule.title,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.cyan,
                    fontSize: 9,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Date pills
              Row(
                children: [
                  _pill(
                    '[ SEALED: ${_formatDate(capsule.createdAt)} ]',
                    AppColors.cyan,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  _pill(
                    '[ UNLOCKED: ${_formatDatetime(capsule.openedAt ?? capsule.unlockDate)} ]',
                    AppColors.cyan,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Hidden photo
              if (content == null) ...[
                if (_loadError == null)
                  const Center(
                    child: CircularProgressIndicator(color: AppColors.yellow),
                  )
                else ...[
                  PixelErrorBox(message: _loadError!),
                  const SizedBox(height: AppSpacing.md),
                  PixelButton(
                    label: '[ RETRY ]',
                    style: PixelButtonStyle.yellow,
                    onPressed: _retry,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],

              if (photoUrl != null) ...[
                Text('HIDDEN PHOTO', style: AppTextStyles.label),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PhotoLightboxScreen(url: photoUrl),
                    ),
                  ),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.charcoal,
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(child: RemotePhoto(photoUrl)),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            color: Colors.black54,
                            child: const Icon(
                              Icons.fullscreen,
                              color: AppColors.cyan,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Secret note
              if (content != null) ...[
                Text('SECRET NOTE', style: AppTextStyles.label),
                const SizedBox(height: 6),
                _insetBox(
                  child: Text(
                    content.secretNote.isEmpty
                        ? '(NO NOTE WRITTEN)'
                        : content.secretNote,
                    style: AppTextStyles.body.copyWith(
                      color: content.secretNote.isEmpty
                          ? AppColors.gray
                          : AppColors.cyan,
                      fontSize: 8,
                      height: 1.7,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Voice note
              if (hasVoice) ...[
                Text('VOICE NOTE', style: AppTextStyles.label),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(3, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _togglePlay,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.yellow,
                            border:
                                Border.all(color: Colors.black, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(2, 2),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            _playerState == PlayerState.playing
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Waveform(
                              progress: _duration.inMilliseconds > 0
                                  ? _position.inMilliseconds /
                                      _duration.inMilliseconds
                                  : 0.0,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        _duration.inSeconds > 0
                            ? _fmt(_duration)
                            : '--:--',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.cyan,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              PixelButton(
                label: '[ CLOSE CHEST ]',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insetBox({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        border: Border.all(color: color, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: color, fontSize: 6),
      ),
    );
  }
}

class _XBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          border: Border.all(color: AppColors.coral, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          '[ X ]',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.coral,
            fontSize: 8,
          ),
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  final double progress;
  const _Waveform({required this.progress});

  static const _bars = [6, 12, 18, 10, 16, 8, 14, 20, 10, 15, 9, 11];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_bars.length, (i) {
          final pct = (i + 1) / _bars.length;
          final played = pct <= progress;
          return Container(
            width: 3,
            height: _bars[i].toDouble(),
            margin: const EdgeInsets.only(right: 2),
            color: played ? AppColors.yellow : AppColors.cyan,
          );
        }),
      ),
    );
  }
}