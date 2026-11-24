import 'package:flutter/material.dart';

import '../../../core/models/memory_model.dart';
import '../../../core/photos/pixel_photo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_controls.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_pressable.dart';

/// A memory or plan in a list: its picture, title and whose it is.
class EntryCard extends StatelessWidget {
  final MemoryModel entry;
  final bool isMine;
  final String partnerName;
  final VoidCallback onTap;

  /// Adds the day, for lists that span a month.
  final bool showDate;

  const EntryCard({
    super.key,
    required this.entry,
    required this.isMine,
    required this.partnerName,
    required this.onTap,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPlan = entry.entryType == MemoryEntryType.plan;
    final count = entry.photoUrls.length;
    final date = ZingDateUtils.fromStored(entry.date);

    return PixelPressable(
      onPressed: onTap,
      builder: (_, pressed) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: PixelRaised(pressed: pressed),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const PixelInset(),
                    clipBehavior: Clip.hardEdge,
                    child: count > 0
                        ? PixelPhoto(PhotoItem.url(entry.photoUrls.first))
                        : Center(
                            child: PixelIcon(
                              isPlan ? PixelIcons.clock : PixelIcons.heart,
                              size: 24,
                              color: isPlan
                                  ? AppColors.yellow
                                  : AppColors.coral,
                            ),
                          ),
                  ),
                  if (count > 1)
                    Positioned(
                      right: 4,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        color: AppColors.ink,
                        child: Text(
                          '$count',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.white,
                            letterSpacing: 0,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDate) ...[
                    Text(
                      '${ZingDateUtils.weekday(date)} '
                      '${ZingDateUtils.monthAbbr(date.month)} ${date.day}'
                      '${isPlan ? ' - PLAN' : ''}',
                      style: AppTextStyles.label.copyWith(
                        color: isPlan ? AppColors.yellow : AppColors.gray,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.button,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: PixelTag.owner(
                          isMine ? 'YOU' : partnerName,
                          isMe: isMine,
                        ),
                      ),
                      if (entry.tagCategory.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            entry.tagCategory,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const PixelIcon(PixelIcons.right, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
