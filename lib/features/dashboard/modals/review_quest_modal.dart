import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pixel_button.dart';
import '../controllers/dashboard_controller.dart';

class ReviewQuestModal extends StatefulWidget {
  const ReviewQuestModal({super.key});

  @override
  State<ReviewQuestModal> createState() => _ReviewQuestModalState();
}

class _ReviewQuestModalState extends State<ReviewQuestModal> {
  bool _submitting = false;

  Future<void> _accept() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await context.read<DashboardController>().acceptQuest();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _decline() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await context.read<DashboardController>().cancelQuest();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final quest = context.watch<DashboardController>().couple?.reunionQuest;
    final destination = quest?.destination ?? '---';
    final targetDate = quest?.targetDate;
    final dateStr = targetDate != null
        ? '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}'
        : '---';
    final notes = quest?.notes;

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
          BoxShadow(color: Colors.black, offset: Offset(5, -5), blurRadius: 0),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REVIEW REUNION\nQUEST',
                style: AppTextStyles.subHeader.copyWith(
                  color: AppColors.cyan,
                  fontSize: 10,
                ),
              ),
              GestureDetector(
                onTap: _submitting ? null : () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.coral,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    '[X]',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.black,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _fieldLabel('DESTINATION'),
          _insetBox(
            child: Text(
              destination,
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontSize: 8,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _fieldLabel('TARGET DATE'),
          _insetBox(
            child: Text(
              dateStr,
              style: AppTextStyles.body.copyWith(
                color: AppColors.yellow,
                fontSize: 8,
              ),
            ),
          ),
          if (notes != null && notes.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _fieldLabel('NOTES'),
            _insetBox(
              child: Text(
                notes,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white54,
                  fontSize: 7,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PixelButton(
            label: _submitting ? '...' : '[ ACCEPT QUEST ]',
            style: PixelButtonStyle.yellow,
            onPressed: _submitting ? null : _accept,
          ),
          const SizedBox(height: AppSpacing.sm),
          PixelButton(
            label: _submitting ? '...' : '[ DECLINE ]',
            style: PixelButtonStyle.coral,
            onPressed: _submitting ? null : _decline,
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
        BoxShadow(color: Colors.black, offset: Offset(0, 3), blurRadius: 0),
      ],
    ),
    child: child,
  );
}
