import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/pixel_decorations.dart';
import 'pixel_icon.dart';
import 'pixel_pressable.dart';

/// Keys sharing one slot, of which exactly one is down.
class PixelSegments extends StatelessWidget {
  final List<String> labels;
  final List<PixelIcons>? icons;
  final int selected;
  final ValueChanged<int>? onSelected;

  const PixelSegments({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.icons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const PixelInset(),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(child: _segment(i)),
        ],
      ),
    );
  }

  Widget _segment(int i) {
    final active = i == selected;
    final tone = active ? PixelTone.yellow : PixelTone.disabled;
    final color = active ? tone.text : AppColors.gray;
    return PixelPressable(
      onPressed: active || onSelected == null ? null : () => onSelected!(i),
      sfx: AppSfx.tick,
      selected: active,
      builder: (_, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 42),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: active
            ? const PixelRaised(tone: PixelTone.yellow, depth: 3, shadow: 0)
            : null,
        child: Center(
          heightFactor: 1,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icons != null) ...[
                  PixelIcon(icons![i], color: color),
                  const SizedBox(width: 6),
                ],
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: AppTextStyles.button.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A key that stays down once chosen.
class PixelChip extends StatelessWidget {
  final String label;
  final PixelIcons? icon;
  final bool selected;
  final VoidCallback? onTap;

  const PixelChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tone = selected ? PixelTone.yellow : PixelTone.neutral;
    return PixelPressable(
      onPressed: onTap,
      sfx: AppSfx.tick,
      selected: selected,
      builder: (_, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: PixelRaised(
          tone: tone,
          depth: 3,
          shadow: 2,
          pressed: pressed || selected,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                PixelIcon(icon!, color: tone.text),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label
                      .copyWith(color: tone.text, letterSpacing: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small flat marker: a tag, a status, whose entry it is.
class PixelTag extends StatelessWidget {
  final String label;
  final PixelIcons? icon;
  final Color color;

  /// Solid tags shout; outlined ones only inform.
  final bool solid;

  const PixelTag(
    this.label, {
    super.key,
    this.icon,
    this.color = AppColors.cyan,
    this.solid = false,
  });

  /// Whose it is: coral for me, cyan for my partner.
  const PixelTag.owner(this.label, {super.key, required bool isMe})
      : color = isMe ? AppColors.coral : AppColors.cyan,
        icon = PixelIcons.user,
        solid = false;

  @override
  Widget build(BuildContext context) {
    final text = solid ? AppColors.ink : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: PixelOutline(
        color: solid ? AppColors.ink : color,
        fill: solid ? color : AppColors.charcoal,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            PixelIcon(icon!, color: text, size: 10),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label
                  .copyWith(color: text, letterSpacing: 0),
            ),
          ),
        ],
      ),
    );
  }
}

/// A slider between off and on.
class PixelSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  const PixelSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final tone = value ? PixelTone.yellow : PixelTone.disabled;
    return PixelPressable(
      onPressed: onChanged == null ? null : () => onChanged!(!value),
      sfx: value ? AppSfx.toggleOff : AppSfx.toggleOn,
      semanticLabel: label,
      toggled: value,
      builder: (_, pressed) => SizedBox(
        width: 68,
        height: 44,
        child: Center(
          child: Container(
            height: 32,
            padding: const EdgeInsets.all(2),
            decoration: PixelInset(
              color: value ? const Color(0xFF5C4708) : AppColors.charcoal,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 90),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 30,
                decoration: PixelRaised(tone: tone, depth: 2, shadow: 0),
                child: Center(
                  child: Container(width: 2, height: 8, color: tone.shade),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A setting: what it is, what it does, and its control.
class PixelSettingRow extends StatelessWidget {
  final PixelIcons icon;
  final String label;
  final String? hint;
  final Widget control;

  const PixelSettingRow({
    super.key,
    required this.icon,
    required this.label,
    required this.control,
    this.hint,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PixelIcon(icon, color: AppColors.gray),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(label, style: AppTextStyles.button)),
              const SizedBox(width: AppSpacing.sm),
              control,
            ],
          ),
          if (hint != null) Text(hint!, style: AppTextStyles.caption),
        ],
      );
}

/// A square box that holds a tick.
class PixelCheckbox extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  const PixelCheckbox({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => PixelPressable(
        onPressed: () => onChanged(!value),
        sfx: value ? AppSfx.toggleOff : AppSfx.toggleOn,
        toggled: value,
        semanticLabel: label,
        builder: (_, pressed) => ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touch),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const PixelInset(),
                child: value
                    ? const Center(
                        child: PixelIcon(PixelIcons.check,
                            color: AppColors.yellow),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(label, style: AppTextStyles.caption)),
            ],
          ),
        ),
      );
}
