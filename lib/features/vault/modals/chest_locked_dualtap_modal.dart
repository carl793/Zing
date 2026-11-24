import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/session_controller.dart';
import '../../../core/models/capsule_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../../../core/widgets/sprite_avatar.dart';
import '../controllers/vault_controller.dart';
import 'locked_chest_page.dart';

class ChestLockedDualTapModal extends StatefulWidget {
  final CapsuleModel capsule;

  /// Both players' sprites.
  final SessionController? session;
  const ChestLockedDualTapModal({
    super.key,
    required this.capsule,
    this.session,
  });

  @override
  State<ChestLockedDualTapModal> createState() =>
      _ChestLockedDualTapModalState();
}

class _ChestLockedDualTapModalState extends State<ChestLockedDualTapModal> {
  bool _tapping = false;
  String? _error;

  Future<void> _tap(CapsuleModel chest) async {
    final vault = context.read<VaultController>();
    setState(() {
      _tapping = true;
      _error = null;
    });
    final error = await vault.tapUnlock(chest);
    if (!mounted) return;
    AudioService.instance.playSfx(error == null ? AppSfx.save : AppSfx.error);
    setState(() {
      _tapping = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LockedChestPage(
      capsule: widget.capsule,
      actions: (vault, chest) {
        final done = vault.myTapDone(chest);
        return PixelButton(
          label: _tapping
              ? 'TAPPING'
              : done
                  ? 'YOU TAPPED'
                  : 'TAP TO UNLOCK',
          icon: done ? PixelIcons.check : PixelIcons.hand,
          busy: _tapping,
          sfx: AppSfx.seal,
          onPressed: done ? null : () => _tap(chest),
        );
      },
      body: (context, vault, chest) => [
        if (_error != null) ...[
          PixelNote.error(_error!),
          const SizedBox(height: AppSpacing.lg),
        ],
        PixelPanel(
          title: 'BOTH MUST TAP',
          icon: PixelIcons.hand,
          child: Row(
            children: [
              Expanded(
                child: _Tapper(
                  user: widget.session?.me,
                  label: 'YOU',
                  tone: PixelTone.coral,
                  done: vault.myTapDone(chest),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Tapper(
                  user: widget.session?.partner,
                  label: vault.partnerName,
                  tone: PixelTone.cyan,
                  done: vault.partnerTapDone(chest),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const PixelNote(
          "You don't have to tap at the same moment. Your tap waits for your "
          "partner's.",
        ),
      ],
    );
  }
}

class _Tapper extends StatelessWidget {
  final UserModel? user;
  final String label;
  final PixelTone tone;
  final bool done;

  const _Tapper({
    required this.user,
    required this.label,
    required this.tone,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final sprite = user?.avatarSpriteId ?? '';
    final avatar = SizedBox.square(
      dimension: 64,
      child: sprite.isEmpty ? null : SpriteAvatar(spriteId: sprite, size: 64),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: PixelInset(outline: done ? tone.face : AppColors.ink),
      child: Column(
        children: [
          Opacity(
            opacity: done ? 1 : 0.45,
            child: done ? SpriteIdle(child: avatar) : avatar,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.button.copyWith(color: tone.face),
          ),
          const SizedBox(height: 4),
          Text(
            done ? 'READY!' : 'WAITING',
            style: AppTextStyles.caption.copyWith(
              color: done ? AppColors.yellow : AppColors.gray,
            ),
          ),
        ],
      ),
    );
  }
}
