import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../theme/pixel_decorations.dart';
import 'pixel_icon.dart';
import 'pixel_pressable.dart';

/// A text field carved into the screen. It lights up while it's being written
/// in, and counts down the last of its characters.
class PixelField extends StatefulWidget {
  final String? label;
  final String hint;
  final TextEditingController controller;
  final PixelIcons? icon;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool hasError;

  /// Hides what's typed behind dots, with an eye to show it.
  final bool secret;
  final Color textColor;
  final TextAlign textAlign;
  final TextStyle? style;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const PixelField({
    super.key,
    this.label,
    required this.hint,
    required this.controller,
    this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.hasError = false,
    this.secret = false,
    this.textColor = AppColors.white,
    this.textAlign = TextAlign.start,
    this.style,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<PixelField> createState() => _PixelFieldState();
}

class _PixelFieldState extends State<PixelField> {
  final FocusNode _focus = FocusNode();
  late bool _hidden = widget.secret;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_redraw);
    widget.controller.addListener(_redraw);
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_redraw);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiline = widget.maxLines > 1;
    final focused = _focus.hasFocus;
    final style = (widget.style ?? AppTextStyles.body).copyWith(
      color: widget.enabled ? widget.textColor : AppColors.faint,
    );
    final limit = widget.maxLength;
    final length = widget.controller.text.characters.length;
    final outline = widget.hasError
        ? AppColors.coral
        : focused
            ? AppColors.cyan
            : AppColors.ink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null)
          _FieldLabel(
            widget.label!,
            color: widget.hasError ? AppColors.coral : AppColors.cyan,
            trailing: focused && limit != null && length * 10 >= limit * 6
                ? '$length/$limit'
                : null,
          ),
        Container(
          decoration: PixelInset(outline: outline),
          constraints: const BoxConstraints(minHeight: AppSpacing.touch),
          child: Row(
            crossAxisAlignment: multiline
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (widget.icon != null)
                Padding(
                  padding: EdgeInsets.only(
                      left: AppSpacing.md, top: multiline ? 17 : 0),
                  child: PixelIcon(
                    widget.icon!,
                    color: focused ? AppColors.cyan : AppColors.faint,
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  obscureText: _hidden,
                  obscuringCharacter: '*',
                  maxLines: multiline ? widget.maxLines + 3 : 1,
                  minLines: widget.maxLines,
                  maxLength: limit,
                  keyboardType: widget.keyboardType,
                  textAlign: widget.textAlign,
                  textCapitalization: widget.textCapitalization,
                  textInputAction: widget.textInputAction,
                  inputFormatters: widget.inputFormatters,
                  autofillHints: widget.autofillHints,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  onTapOutside: (_) => _focus.unfocus(),
                  cursorColor: AppColors.yellow,
                  cursorWidth: 6,
                  cursorRadius: Radius.zero,
                  style: style,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintMaxLines: multiline ? 3 : 1,
                    hintStyle: AppTextStyles.body.copyWith(
                      color: AppColors.faint,
                      letterSpacing: 0,
                      shadows: const [],
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              if (widget.secret)
                PixelPressable(
                  semanticLabel: _hidden ? 'Show' : 'Hide',
                  sfx: AppSfx.tick,
                  onPressed: () => setState(() => _hidden = !_hidden),
                  builder: (_, pressed) => SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: PixelIcon(
                        _hidden ? PixelIcons.eye : PixelIcons.eyeOff,
                        color: pressed ? AppColors.yellow : AppColors.gray,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A value shown like a field. Tapping it, when possible, opens a picker.
class PixelValueBox extends StatelessWidget {
  final String? label;
  final String text;
  final Color textColor;
  final PixelIcons? icon;
  final VoidCallback? onTap;
  final bool hasError;

  const PixelValueBox({
    super.key,
    this.label,
    required this.text,
    this.textColor = AppColors.white,
    this.icon,
    this.onTap,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: AppSpacing.touch),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration:
          PixelInset(outline: hasError ? AppColors.coral : AppColors.ink),
      child: Row(
        children: [
          if (icon != null) ...[
            PixelIcon(icon!, color: textColor),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                text,
                style: AppTextStyles.body.copyWith(
                  color: textColor,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (onTap != null)
            const PixelIcon(PixelIcons.down, color: AppColors.yellow),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) _FieldLabel(label!),
        if (onTap == null)
          box
        else
          PixelPressable(
            onPressed: onTap,
            builder: (_, pressed) => Opacity(
              opacity: pressed ? 0.75 : 1,
              child: box,
            ),
          ),
      ],
    );
  }
}

/// A label above anything that isn't a field itself.
class PixelLabel extends StatelessWidget {
  final String text;
  final String? trailing;
  const PixelLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => _FieldLabel(text, trailing: trailing);
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;
  final String? trailing;
  const _FieldLabel(this.text, {this.color = AppColors.cyan, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Row(
          children: [
            Expanded(
              child:
                  Text(text, style: AppTextStyles.label.copyWith(color: color)),
            ),
            if (trailing != null)
              Text(trailing!, style: AppTextStyles.label.copyWith(
                color: AppColors.gray,
              )),
          ],
        ),
      );
}
