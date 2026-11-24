import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/capsule_model.dart';
import '../../../core/permissions/permission_flows.dart';
import '../../../core/photos/photo_viewer.dart';
import '../../../core/photos/pixel_photo.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../controllers/vault_controller.dart';
import '../controllers/voice_recorder.dart';

class CreateCapsuleModal extends StatefulWidget {
  const CreateCapsuleModal({super.key});

  @override
  State<CreateCapsuleModal> createState() => _CreateCapsuleModalState();
}

class _CreateCapsuleModalState extends State<CreateCapsuleModal> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _unlockDate;
  String? _formError;

  // The draft belongs to this form: closing it throws everything away and
  // stops the microphone.
  final _voice = VoiceRecorder();
  CapsuleTriggerMode _trigger = CapsuleTriggerMode.dateRelease;
  Uint8List? _photo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoice);
  }

  void _onVoice() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoice);
    _voice.dispose();
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool _hasUnsavedWork() =>
      _titleCtrl.text.trim().isNotEmpty ||
      _noteCtrl.text.trim().isNotEmpty ||
      _photo != null ||
      _voice.status != VoiceStatus.idle;

  Future<void> _pickDateTime() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final current = _unlockDate;
    final date = await showDatePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDate: current ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialEntryMode: TimePickerEntryMode.dialOnly,
      initialTime: current == null
          ? const TimeOfDay(hour: 12, minute: 0)
          : TimeOfDay.fromDateTime(current),
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
    });
  }

  Future<void> _choosePhoto() async {
    FocusScope.of(context).unfocus();
    final picked = await pickPhotos(
      context,
      settings: context.read<LocationService>(),
    );
    if (picked.isNotEmpty && mounted) setState(() => _photo = picked.first);
  }

  Future<void> _record() async {
    FocusScope.of(context).unfocus();
    final granted = await ensureMicrophoneAccess(
      context,
      hasPermission: _voice.hasPermission,
      settings: context.read<LocationService>(),
    );
    if (!granted || !mounted) return;
    final started = await _voice.start();
    if (!started && mounted) {
      setState(() => _formError =
          "COULDN'T START RECORDING. IS ANOTHER APP USING THE MICROPHONE?");
    }
  }

  String? _problem(String title) {
    if (title.isEmpty) return 'GIVE YOUR CHEST A NAME.';
    if (_trigger != CapsuleTriggerMode.dateRelease) return null;
    final date = _unlockDate;
    if (date == null) return 'SET A DATE AND TIME.';
    if (!date.isAfter(DateTime.now())) return 'PICK A TIME IN THE FUTURE.';
    return null;
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final problem = _problem(title);
    if (problem != null) {
      AudioService.instance.playSfx(AppSfx.error);
      setState(() => _formError = problem);
      return;
    }
    FocusScope.of(context).unfocus();
    final ctrl = context.read<VaultController>();
    setState(() {
      _saving = true;
      _formError = null;
    });
    await _voice.stop();

    final error = await ctrl.createCapsule(
      trigger: _trigger,
      title: title,
      secretNote: _noteCtrl.text.trim(),
      unlockDate: _unlockDate,
      photo: _photo,
      voiceNotePath: _voice.path,
    );

    if (!mounted) return;
    if (error != null) {
      AudioService.instance.playSfx(AppSfx.error);
      setState(() {
        _saving = false;
        _formError = error;
      });
      return;
    }
    AudioService.instance
      ..playSfx(AppSfx.seal)
      ..knock(strong: true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDate = _trigger == CapsuleTriggerMode.dateRelease;
    final date = _unlockDate;

    return PixelModalShell(
      title: 'NEW CHEST',
      icon: PixelIcons.chest,
      titleColor: AppColors.yellow,
      busy: _saving,
      hasUnsavedWork: _hasUnsavedWork,
      footer: PixelButton(
        label: _saving ? 'SEALING' : 'SEAL CHEST',
        icon: PixelIcons.lock,
        busy: _saving,
        onPressed: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_formError != null) ...[
            PixelNote.error(_formError!),
            const SizedBox(height: AppSpacing.lg),
          ],
          const PixelLabel('OPENS'),
          PixelSegments(
            labels: const ['ON A DATE', 'DUAL TAP'],
            icons: const [PixelIcons.clock, PixelIcons.hand],
            selected: isDate ? 0 : 1,
            onSelected: _saving
                ? null
                : (i) => setState(() => _trigger = i == 0
                    ? CapsuleTriggerMode.dateRelease
                    : CapsuleTriggerMode.dualTapSync),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isDate)
            PixelValueBox(
              icon: PixelIcons.calendar,
              text: date == null
                  ? 'TAP TO CHOOSE WHEN'
                  : ZingDateUtils.dateTimeLabel(date),
              textColor: date == null ? AppColors.faint : AppColors.yellow,
              hasError: _formError != null && date == null,
              onTap: _saving ? null : _pickDateTime,
            )
          else
            const PixelNote('Opens once both of you have tapped it.'),
          const SizedBox(height: AppSpacing.lg),
          PixelField(
            label: 'CHEST NAME',
            hint: 'Open on your flight home',
            controller: _titleCtrl,
            maxLength: 60,
            enabled: !_saving,
            hasError: _formError != null && _titleCtrl.text.trim().isEmpty,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.lg),
          PixelField(
            label: 'SECRET NOTE',
            hint: 'Read this when your plane takes off...',
            controller: _noteCtrl,
            maxLines: 4,
            maxLength: 500,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.lg),
          const PixelLabel('HIDDEN PHOTO'),
          _photoBox(),
          const SizedBox(height: AppSpacing.lg),
          const PixelLabel('VOICE NOTE'),
          _voiceBox(),
          const SizedBox(height: AppSpacing.lg),
          const PixelNote.warning(
            "Once sealed, a chest can't be edited, and nobody sees inside "
            'until it opens.',
          ),
        ],
      ),
    );
  }

  Widget _photoBox() {
    final photo = _photo;
    if (photo == null) {
      return PixelButton(
        label: 'ADD A PHOTO',
        icon: PixelIcons.photo,
        style: PixelButtonStyle.neutral,
        small: true,
        onPressed: _saving ? null : _choosePhoto,
      );
    }
    final item = PhotoItem.bytes(photo);
    return PixelWell(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => PhotoViewer.open(context, photos: [item]),
            child: Container(
              width: 64,
              height: 64,
              decoration: const PixelOutline(color: AppColors.ink),
              clipBehavior: Clip.hardEdge,
              child: PixelPhoto(item),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text('PHOTO ADDED', style: AppTextStyles.button),
          ),
          PixelIconButton(
            icon: PixelIcons.trash,
            label: 'Remove photo',
            tone: PixelTone.danger,
            onPressed: _saving ? null : () => setState(() => _photo = null),
          ),
        ],
      ),
    );
  }

  Widget _voiceBox() {
    final seconds = _voice.elapsed.inSeconds;
    final clock = '0:${seconds.toString().padLeft(2, '0')}';

    return switch (_voice.status) {
      VoiceStatus.idle => PixelButton(
          label: 'RECORD',
          icon: PixelIcons.mic,
          style: PixelButtonStyle.neutral,
          small: true,
          onPressed: _saving ? null : _record,
        ),
      VoiceStatus.recording => PixelWell(
          outline: AppColors.coral,
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              PixelIconButton(
                icon: PixelIcons.stop,
                label: 'Stop recording',
                tone: PixelTone.coral,
                onPressed: _voice.stop,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PixelProgressBar(
                  value: seconds / VoiceRecorder.maxLength.inSeconds,
                  tone: PixelTone.coral,
                  blocks: 12,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                clock,
                style: AppTextStyles.button.copyWith(color: AppColors.coral),
              ),
            ],
          ),
        ),
      VoiceStatus.recorded => PixelWell(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.sm),
              const PixelIcon(PixelIcons.mic, size: 18, color: AppColors.cyan),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('VOICE ADDED\n$clock', style: AppTextStyles.button),
              ),
              PixelIconButton(
                icon: PixelIcons.trash,
                label: 'Remove voice note',
                tone: PixelTone.danger,
                onPressed: _saving ? null : _voice.discard,
              ),
            ],
          ),
        ),
    };
  }
}
