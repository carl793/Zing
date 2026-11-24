import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/comment_model.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pixel_decorations.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/pixel_button.dart';
import '../../../core/widgets/pixel_field.dart';
import '../../../core/widgets/pixel_icon.dart';
import '../../../core/widgets/pixel_panel.dart';
import '../controllers/calendar_controller.dart';

/// Live comment feed for one memory. Only the partner of the entry's author
/// can post ([canComment]); both partners can read.
class CommentsSection extends StatefulWidget {
  final MemoryModel memory;
  final bool canComment;

  const CommentsSection({
    super.key,
    required this.memory,
    required this.canComment,
  });

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  late final Stream<List<CommentModel>> _stream;
  final _input = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stream =
        context.read<CalendarController>().streamComments(widget.memory.memoryId);
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending || !widget.canComment) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await context
        .read<CalendarController>()
        .addComment(widget.memory, text);
    if (!mounted) return;
    if (error == null) AudioService.instance.playSfx(AppSfx.save);
    setState(() {
      _sending = false;
      _error = error;
      if (error == null) _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<CalendarController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PixelLabel('COMMENTS'),
        PixelWell(
          child: StreamBuilder<List<CommentModel>>(
            stream: _stream,
            builder: (context, snapshot) {
              final comments = snapshot.data ?? const <CommentModel>[];
              if (comments.isEmpty) {
                return Text(
                  widget.canComment
                      ? 'No comments yet. Leave the first one.'
                      : 'No comments yet. Only ${ctrl.partnerName} can comment '
                          'on your entry.',
                  style: AppTextStyles.caption,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, comment) in comments.indexed) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _Bubble(
                      comment: comment,
                      mine: ctrl.isMine(comment.authorUid),
                      name: ctrl.nameFor(comment.authorUid),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          PixelNote.error(_error!),
        ],
        if (widget.canComment) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: PixelField(
                  hint: 'Say something...',
                  controller: _input,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PixelIconButton(
                icon: PixelIcons.send,
                label: 'Send',
                tone: PixelTone.coral,
                size: 48,
                onPressed:
                    _sending || _input.text.trim().isEmpty ? null : _send,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final CommentModel comment;
  final bool mine;
  final String name;
  const _Bubble({
    required this.comment,
    required this.mine,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final color = mine ? AppColors.coral : AppColors.cyan;
    return Column(
      crossAxisAlignment:
          mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          margin: EdgeInsets.only(left: mine ? 24 : 0, right: mine ? 0 : 24),
          decoration: PixelOutline(color: color, fill: AppColors.purple),
          child: Text(comment.text, style: AppTextStyles.body),
        ),
        const SizedBox(height: 4),
        Text(
          '$name, ${ZingDateUtils.shortLabel(ZingDateUtils.fromLocal(comment.createdAt))}',
          style: AppTextStyles.caption.copyWith(color: color),
        ),
      ],
    );
  }
}
