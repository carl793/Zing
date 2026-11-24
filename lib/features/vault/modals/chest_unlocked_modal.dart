import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/material.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/photos/photo_carousel.dart';
import '../../../core/photos/pixel_photo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_loader.dart';
import '../../../core/widgets/pixel_page.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../widgets/chest_stage.dart';
import '../widgets/voice_player.dart';

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
  CapsuleContent? _content;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  @override
  Widget build(BuildContext context) {
    final capsule = widget.capsule;
    final content = _content;
    final opened = capsule.openedAt ?? capsule.unlockDate;

    return PixelPage(
      title: 'TREASURE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ChestStage(open: true, size: 96),
          const SizedBox(height: AppSpacing.lg),
          Text(
            capsule.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.subHeader,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              PixelTag(
                ZingDateUtils.shortLabel(
                    ZingDateUtils.fromLocal(capsule.createdAt)),
                icon: PixelIcons.lock,
                color: AppColors.gray,
              ),
              if (opened != null)
                PixelTag(
                  ZingDateUtils.shortLabel(ZingDateUtils.fromLocal(opened)),
                  icon: PixelIcons.unlock,
                  color: AppColors.yellow,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (content != null)
            ..._inside(content, capsule.title)
          else if (_loadError == null)
            const PixelLoading(label: 'OPENING...')
          else ...[
            PixelNote.error(_loadError!),
            const SizedBox(height: AppSpacing.md),
            PixelButton(
              label: 'RETRY',
              icon: PixelIcons.refresh,
              onPressed: _retry,
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _inside(CapsuleContent content, String title) {
    final photoUrl = content.photoUrl;
    final voiceUrl = content.voiceNoteUrl;
    return [
      if (photoUrl != null) ...[
        PhotoCarousel(photos: [PhotoItem.url(photoUrl)], title: title),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (voiceUrl != null) ...[
        const PixelLabel('VOICE NOTE'),
        VoicePlayer(url: voiceUrl),
        const SizedBox(height: AppSpacing.lg),
      ],
      const PixelLabel('SECRET NOTE'),
      PixelWell(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: content.secretNote.isEmpty
            ? Text('No note was written.', style: AppTextStyles.caption)
            : SelectableText(content.secretNote, style: AppTextStyles.body),
      ),
    ];
  }
}
