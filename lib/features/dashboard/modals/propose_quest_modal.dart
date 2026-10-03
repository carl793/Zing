import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_button.dart';
import '../controllers/dashboard_controller.dart';

class ProposeQuestModal extends StatefulWidget {
  const ProposeQuestModal({super.key});

  @override
  State<ProposeQuestModal> createState() => _ProposeQuestModalState();
}

class _ProposeQuestModalState extends State<ProposeQuestModal> {
  final _destination = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _selectedDate;
  bool _saving = false;

  @override
  void dispose() {
    _destination.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (_destination.text.trim().isEmpty || _selectedDate == null) return;
    setState(() => _saving = true);
    await context.read<DashboardController>().proposeQuest(
          destination: _destination.text.trim().toUpperCase(),
          targetDate: _selectedDate!,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        top: AppSpacing.lg,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.purple,
        border: Border(
          top: BorderSide(color: Colors.black, width: 2),
          left: BorderSide(color: Colors.black, width: 2),
          right: BorderSide(color: Colors.black, width: 2),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black, offset: Offset(5, -5), blurRadius: 0)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PROPOSE REUNION\nQUEST',
                  style: AppTextStyles.subHeader
                      .copyWith(color: AppColors.cyan, fontSize: 10)),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 0)
                    ],
                  ),
                  child: Text('[X]',
                      style: AppTextStyles.caption
                          .copyWith(color: Colors.black, fontSize: 8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _fieldLabel('DESTINATION'),
          _insetBox(
            child: TextField(
              controller: _destination,
              textCapitalization: TextCapitalization.characters,
              style: AppTextStyles.body
                  .copyWith(color: Colors.white, fontSize: 8),
              cursorColor: AppColors.cyan,
              decoration: _inputDeco('DAVAO CITY, PHILIPPINES'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _fieldLabel('TARGET DATE'),
          GestureDetector(
            onTap: _pickDate,
            child: _insetBox(
              child: Text(
                _selectedDate != null
                    ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                    : 'TAP TO SELECT DATE..',
                style: AppTextStyles.body.copyWith(
                  color: _selectedDate != null
                      ? AppColors.yellow
                      : const Color(0xFF555577),
                  fontSize: 8,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _fieldLabel('NOTES (OPTIONAL)'),
          _insetBox(
            child: TextField(
              controller: _notes,
              maxLines: 2,
              style: AppTextStyles.body
                  .copyWith(color: Colors.white54, fontSize: 7),
              cursorColor: AppColors.cyan,
              decoration: _inputDeco('BOOK FLIGHTS BY END OF SEPTEMBER...'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PixelButton(
            label: _saving ? '...' : '[ PROPOSE QUEST ]',
            style: PixelButtonStyle.coral,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text, style: AppTextStyles.label),
      );

  Widget _insetBox({required Widget child}) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.charcoal,
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black, offset: Offset(0, 3), blurRadius: 0)
          ],
        ),
        child: child,
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.body
            .copyWith(color: const Color(0xFF555577), fontSize: 7),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      );
}