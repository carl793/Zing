import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/sprite_avatar.dart';
import '../controllers/vault_controller.dart';
import 'chest_unlocked_modal.dart';

class ChestLockedDateModal extends StatefulWidget {
  final CapsuleModel capsule;
  const ChestLockedDateModal({super.key, required this.capsule});

  @override
  State<ChestLockedDateModal> createState() => _ChestLockedDateModalState();
}

class _ChestLockedDateModalState extends State<ChestLockedDateModal> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _compute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _compute());
  }

  void _compute() {
    final unlock = widget.capsule.unlockDate;
    if (unlock == null) return;
    final now = DateTime.now();
    if (!unlock.isAfter(now))
      context.read<VaultController>().refreshDueUnlocks();
    final sealed = widget.capsule.createdAt;
    final total = unlock.difference(sealed).inSeconds;
    final remaining = unlock.difference(now);
    if (!mounted) return;
    setState(() {
      _remaining = remaining.isNegative ? Duration.zero : remaining;
      final elapsed = total - remaining.inSeconds;
      _progress = (total > 0 ? elapsed / total : 0.0)
          .clamp(0.0, 1.0)
          .toDouble();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdownText {
    final d = _remaining.inDays;
    final h = _remaining.inHours % 24;
    final m = _remaining.inMinutes % 60;
    return '${d}D:${h.toString().padLeft(2, '0')}H:${m.toString().padLeft(2, '0')}M';
  }

  String get _targetText {
    final u = widget.capsule.unlockDate!;
    final h12 = u.hour % 12 == 0 ? 12 : u.hour % 12;
    final m = u.minute.toString().padLeft(2, '0');
    final ampm = u.hour < 12 ? 'AM' : 'PM';
    return 'TARGET DATE: ${u.year}-${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')} @ $h12:$m $ampm';
  }

  bool get _isMyChest =>
      context.read<VaultController>().isMyChest(widget.capsule);

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<VaultController>();
    final capsule =
        ctrl.capsuleById(widget.capsule.capsuleId) ?? widget.capsule;
    if (capsule.status == CapsuleStatus.unlocked) {
      return Scaffold(
        backgroundColor: AppColors.navy,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'CHEST UNLOCKED',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.header.copyWith(color: AppColors.yellow),
                ),
                const SizedBox(height: AppSpacing.lg),
                PixelButton(
                  label: '[ OPEN CHEST ]',
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: ctrl,
                          child: ChestUnlockedModal(capsule: capsule),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                PixelButton(
                  label: '[ CLOSE ]',
                  style: PixelButtonStyle.outline,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHEST SEALED',
                    style: AppTextStyles.header.copyWith(
                      color: AppColors.coral,
                      fontSize: 18,
                      shadows: const [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                  ),
                  _CloseBtn(),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                '"${widget.capsule.title}"',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.cyan,
                  fontSize: 10,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              const Center(
                child: SpriteAssetIcon(
                  assetPath: 'assets/sprites/mystery_box.svg',
                  fallbackPath: 'assets/sprites/mystery_box_96.png',
                  size: 84,
                  semanticsLabel: 'Mystery box chest',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'LOCKED',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.yellow,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                'UNLOCKS IN',
                textAlign: TextAlign.center,
                style: AppTextStyles.label.copyWith(color: AppColors.cyan),
              ),
              const SizedBox(height: AppSpacing.sm),

              Text(
                _countdownText,
                textAlign: TextAlign.center,
                style: AppTextStyles.header.copyWith(
                  color: AppColors.yellow,
                  fontSize: 22,
                  shadows: const [
                    Shadow(
                      color: Colors.black,
                      offset: Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Progress bar
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.charcoal,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progress,
                  child: Container(color: AppColors.gray),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: AppColors.charcoal,
                child: Text(
                  _targetText,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.cyan,
                    fontSize: 7,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'Sealed chests cannot be opened before their release conditions are met.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.gray,
                  fontSize: 6,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Cancel option only for creator
              if (_isMyChest) ...[
                GestureDetector(
                  onTap: () => _cancel(context),
                  child: Center(
                    child: Text(
                      '[ CANCEL CHEST ]',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.coral,
                        fontSize: 6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              PixelButton(
                label: '[ CLOSE ]',
                style: PixelButtonStyle.outline,
                backgroundColor: AppColors.charcoal,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final ctrl = context.read<VaultController>();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _CancelDialog(chestName: widget.capsule.title),
    );
    if (confirmed != true || !mounted) return;
    final error = await ctrl.cancelCapsule(widget.capsule);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    }
  }
}

class _CloseBtn extends StatelessWidget {
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
            BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
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

class _CancelDialog extends StatelessWidget {
  final String chestName;
  const _CancelDialog({required this.chestName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.purple,
          border: Border.all(color: AppColors.coral, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.amber,
              size: 34,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'CANCEL THIS\nCHEST?',
              textAlign: TextAlign.center,
              style: AppTextStyles.subHeader.copyWith(
                color: AppColors.coral,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'This will permanently delete\n"$chestName" and everything sealed inside it.\nThis cannot be undone.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.gray,
                fontSize: 6,
                height: 1.8,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PixelButton(
              label: '[ KEEP SEALED ]',
              style: PixelButtonStyle.outline,
              backgroundColor: AppColors.charcoal,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AppSpacing.md),
            PixelButton(
              label: '[ YES, CANCEL CHEST ]',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
