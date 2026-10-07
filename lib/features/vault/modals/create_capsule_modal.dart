import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_error_box.dart';
import '../../../core/widgets/pixel_inset_field.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../../../core/widgets/sprite_avatar.dart';
import '../controllers/vault_controller.dart';

class CreateCapsuleModal extends StatefulWidget {
  const CreateCapsuleModal({super.key});

  @override
  State<CreateCapsuleModal> createState() => _CreateCapsuleModalState();
}

class _CreateCapsuleModalState extends State<CreateCapsuleModal> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _unlockDate;
  TimeOfDay _unlockTime = const TimeOfDay(hour: 12, minute: 0);
  String? _formError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().add(const Duration(hours: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.yellow,
            surface: AppColors.purple,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _unlockTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.yellow,
            surface: AppColors.purple,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _unlockDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _unlockTime = time;
    });
  }

  String get _unlockDateDisplay {
    if (_unlockDate == null) return 'TAP TO SET DATE & TIME..';
    final d = _unlockDate!;
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} @ $h12:$m $ampm';
  }

  Future<void> _save() async {
    final ctrl = context.read<VaultController>();
    setState(() => _formError = null);

    final error = await ctrl.createCapsule(
      title: _titleCtrl.text,
      secretNote: _noteCtrl.text,
      unlockDate: _unlockDate,
    );

    if (!mounted) return;
    if (error != null) {
      setState(() => _formError = error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<VaultController>();
    final isDate = ctrl.draftTrigger == CapsuleTriggerMode.dateRelease;

    return PixelModalShell(
      title: 'CRAFT TREASURE\nCHEST',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: SpriteAssetIcon(
              assetPath: 'assets/sprites/mystery_box.svg',
              fallbackPath: 'assets/sprites/mystery_box_96.png',
              size: 44,
              semanticsLabel: 'Mystery box chest',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Trigger mode tabs
          Row(
            children: [
              Expanded(
                child: _TriggerTab(
                  label: '[ DATE\nRELEASE ]',
                  active: isDate,
                  onTap: () => ctrl.setDraftTrigger(CapsuleTriggerMode.dateRelease),
                ),
              ),
              Expanded(
                child: _TriggerTab(
                  label: '[ DUAL-TAP\nSYNC ]',
                  active: !isDate,
                  onTap: () => ctrl.setDraftTrigger(CapsuleTriggerMode.dualTapSync),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Chest name
          PixelInsetField(
            label: 'CHEST NAME',
            hint: 'OPEN ON YOUR FLIGHT HOME..',
            controller: _titleCtrl,
            maxLength: 60,
            enabled: !ctrl.isSaving,
          ),
          const SizedBox(height: AppSpacing.md),

          // Date/time picker — only for date-release
          if (isDate) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UNLOCK DATE & TIME', style: AppTextStyles.label),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: ctrl.isSaving ? null : _pickDateTime,
                  child: Container(
                    width: double.infinity,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 12, color: AppColors.cyan),
                        const SizedBox(width: 8),
                        Text(
                          _unlockDateDisplay,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 7,
                            color: _unlockDate != null
                                ? AppColors.yellow
                                : const Color(0xFF555577),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Secret note
          PixelInsetField(
            label: 'SECRET NOTE',
            hint: 'Read this when your plane takes off...',
            controller: _noteCtrl,
            maxLines: 4,
            maxLength: 500,
            enabled: !ctrl.isSaving,
          ),
          const SizedBox(height: AppSpacing.md),

          // Media buttons
          Text('ATTACH HIDDEN MEDIA', style: AppTextStyles.label),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _MediaButton(
                  label: ctrl.draftPhotoBytes != null
                      ? '[ ✓ PHOTO ADDED ]'
                      : '[ + HIDDEN PHOTO ]',
                  icon: Icons.image,
                  active: ctrl.draftPhotoBytes != null,
                  onTap: ctrl.isSaving
                      ? null
                      : (ctrl.draftPhotoBytes != null
                          ? ctrl.clearChestPhoto
                          : ctrl.pickChestPhoto),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MediaButton(
                  label: ctrl.isRecording
                      ? '[ ■ STOP ]'
                      : (ctrl.draftVoiceNotePath != null
                          ? '[ ✓ VOICE ADDED ]'
                          : '[ (mic) RECORD\nVOICE NOTE ]'),
                  icon: ctrl.isRecording ? Icons.stop : Icons.mic,
                  active: ctrl.draftVoiceNotePath != null,
                  onTap: ctrl.isSaving
                      ? null
                      : (ctrl.isRecording
                          ? ctrl.stopRecording
                          : (ctrl.draftVoiceNotePath != null
                              ? ctrl.clearVoiceNote
                              : ctrl.startRecording)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Warning box
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.charcoal,
              border: Border.all(color: AppColors.yellow, width: 2),
            ),
            child: Text(
              '/!\\ ONCE LOCKED, THIS CHEST IS SEALED UNTIL THE RELEASE CONDITIONS ARE MET.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.yellow,
                fontSize: 6,
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (_formError != null) ...[
            PixelErrorBox(message: _formError!),
            const SizedBox(height: AppSpacing.md),
          ],

          PixelButton(
            label: ctrl.isSaving ? 'SEALING...' : '[ LOCK & SEAL CHEST ]',
            style: PixelButtonStyle.yellow,
            onPressed: ctrl.isSaving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _TriggerTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TriggerTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.yellow : Colors.transparent,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.button.copyWith(
            fontSize: 7,
            color: active ? Colors.black : Colors.white,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  const _MediaButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.cyan.withOpacity(0.1)
              : AppColors.charcoal,
          border: Border.all(
            color: active ? AppColors.cyan : AppColors.cyan,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? AppColors.cyan : AppColors.cyan),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                fontSize: 6,
                color: AppColors.cyan,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}