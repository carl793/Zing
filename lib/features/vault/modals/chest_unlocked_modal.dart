import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';
import 'photo_lightbox_screen.dart';

class ChestUnlockedModal extends StatefulWidget {
  final CapsuleModel capsule;
  const ChestUnlockedModal({super.key, required this.capsule});

  @override
  State<ChestUnlockedModal> createState() => _ChestUnlockedModalState();
}

class _ChestUnlockedModalState extends State<ChestUnlockedModal> {
  final _player = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final url = widget.capsule.voiceNoteUrl;
    if (url == null) return;

    if (_playerState == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(url));
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
    final hasPhoto = capsule.photoUrl != null && capsule.photoUrl!.isNotEmpty;
    final hasVoice =
        capsule.voiceNoteUrl != null && capsule.voiceNoteUrl!.isNotEmpty;

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
              Text('HIDDEN PHOTO', style: AppTextStyles.label),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: hasPhoto
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PhotoLightboxScreen(url: capsule.photoUrl!),
                          ),
                        )
                    : null,
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
                  child: hasPhoto
                      ? Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(
                                capsule.photoUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, progress) =>
                                    progress == null
                                        ? child
                                        : const Center(
                                            child: CircularProgressIndicator(
                                              color: AppColors.yellow,
                                            ),
                                          ),
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: AppColors.gray,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
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
                        )
                      : Center(
                          child: Text(
                            '[ REVEALED PHOTO\nATTACHMENT ]',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.gray,
                              fontSize: 6,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Secret note
              Text('SECRET NOTE', style: AppTextStyles.label),
              const SizedBox(height: 6),
              _insetBox(
                child: Text(
                  capsule.secretNote.isEmpty
                      ? '(NO NOTE WRITTEN)'
                      : capsule.secretNote,
                  style: AppTextStyles.body.copyWith(
                    color: capsule.secretNote.isEmpty
                        ? AppColors.gray
                        : AppColors.cyan,
                    fontSize: 8,
                    height: 1.7,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

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