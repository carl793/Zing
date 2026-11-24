import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_modal_shell.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../controllers/dashboard_controller.dart';

class ProposeQuestModal extends StatefulWidget {
  const ProposeQuestModal({super.key});

  @override
  State<ProposeQuestModal> createState() => _ProposeQuestModalState();
}

class _ProposeQuestModalState extends State<ProposeQuestModal> {
  final _destination = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _date;
  bool _saving = false;
  bool _missing = false;
  String? _error;

  @override
  void dispose() {
    _destination.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDate: _date ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final destination = _destination.text.trim();
    final date = _date;
    if (destination.isEmpty || date == null) {
      setState(() {
        _missing = true;
        _error = 'ADD A DESTINATION AND A DATE.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final notes = _notes.text.trim();
    final error = await context.read<DashboardController>().proposeQuest(
          destination: destination.toUpperCase(),
          targetDate: date,
          notes: notes.isEmpty ? null : notes,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    AudioService.instance.playSfx(AppSfx.save);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    return PixelModalShell(
      title: 'PROPOSE A QUEST',
      icon: PixelIcons.flag,
      titleColor: AppColors.yellow,
      busy: _saving,
      hasUnsavedWork: () =>
          _destination.text.trim().isNotEmpty ||
          _notes.text.trim().isNotEmpty ||
          _date != null,
      footer: PixelButton(
        label: _saving ? 'SENDING' : 'PROPOSE QUEST',
        icon: PixelIcons.send,
        busy: _saving,
        onPressed: _submit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            PixelNote.error(_error!),
            const SizedBox(height: AppSpacing.lg),
          ],
          PixelField(
            label: 'DESTINATION',
            hint: 'Davao City',
            icon: PixelIcons.pin,
            controller: _destination,
            maxLength: 40,
            enabled: !_saving,
            hasError: _missing && _destination.text.trim().isEmpty,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.lg),
          PixelValueBox(
            label: 'DATE',
            icon: PixelIcons.calendar,
            text: date == null
                ? 'TAP TO CHOOSE'
                : ZingDateUtils.shortLabel(ZingDateUtils.fromLocal(date)),
            textColor: date == null ? AppColors.faint : AppColors.yellow,
            hasError: _missing && date == null,
            onTap: _saving ? null : _pickDate,
          ),
          const SizedBox(height: AppSpacing.lg),
          PixelField(
            label: 'NOTES (OPTIONAL)',
            hint: 'Book flights by September...',
            controller: _notes,
            maxLines: 3,
            maxLength: 200,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}
