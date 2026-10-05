import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// Editable inset text field (single or multi-line) with an optional label.
class PixelInsetField extends StatefulWidget {
  final String? label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool hasError;
  final IconData? prefixIcon;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  const PixelInsetField({
    super.key,
    this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.hasError = false,
    this.prefixIcon,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  @override
  State<PixelInsetField> createState() => _PixelInsetFieldState();
}

class _PixelInsetFieldState extends State<PixelInsetField> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multiline = widget.maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: AppTextStyles.label),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: AppShadows.insetField(
            hasError: widget.hasError,
            hasFocus: _focused,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment:
                multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              if (widget.prefixIcon != null) ...[
                Icon(widget.prefixIcon, size: 12, color: AppColors.cyan),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  maxLines: widget.maxLines,
                  minLines: multiline ? widget.maxLines : 1,
                  maxLength: widget.maxLength,
                  textCapitalization: widget.textCapitalization,
                  onChanged: widget.onChanged,
                  cursorColor: AppColors.cyan,
                  style: AppTextStyles.body.copyWith(
                    color: widget.enabled ? Colors.white : AppColors.gray,
                    fontSize: 8,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: AppTextStyles.body.copyWith(
                      color: const Color(0xFF555577),
                      fontSize: 8,
                      height: 1.6,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
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

/// Read-only (optionally tappable) inset box, e.g. a date or a tag dropdown.
class PixelInsetBox extends StatelessWidget {
  final String? label;
  final String text;
  final Color textColor;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const PixelInsetBox({
    super.key,
    this.label,
    required this.text,
    this.textColor = Colors.white,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTextStyles.label),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: double.infinity,
            decoration: AppShadows.insetField(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body
                        .copyWith(color: textColor, fontSize: 8),
                  ),
                ),
                if (trailingIcon != null)
                  Icon(trailingIcon, size: 16, color: textColor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}