import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/models/memory_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pixel_error_box.dart';
import '../../../core/widgets/pixel_inset_field.dart';
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
    setState(() {
      _sending = false;
      _error = error;
      if (error == null) _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<CalendarController>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF242149),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(3, 3), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PARTNER LOG COMMENTS',
            style: AppTextStyles.label.copyWith(color: AppColors.cyan, fontSize: 7),
          ),
          const SizedBox(height: AppSpacing.sm),
          StreamBuilder<List<CommentModel>>(
            stream: _stream,
            builder: (context, snapshot) {
              final comments = snapshot.data ?? const <CommentModel>[];
              if (comments.isEmpty) {
                return Text('NO COMMENTS YET.', style: AppTextStyles.caption);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: comments.map((c) {
                  final mine = ctrl.isMine(c.authorUid);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${ctrl.nameFor(c.authorUid)}: ${c.text}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 6,
                        height: 1.7,
                        color: mine ? AppColors.coral : AppColors.cyan,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (_error != null) ...[
            PixelErrorBox(message: _error!),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: PixelInsetField(
                  hint: widget.canComment ? 'ADD COMMENT...' : 'PARTNER COMMENTS ONLY',
                  controller: _input,
                  enabled: widget.canComment,
                  maxLength: 200,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SendButton(
                enabled: widget.canComment && !_sending,
                onTap: _send,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _SendButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? AppColors.coral : const Color(0xFF555555),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: enabled
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
          '[SEND]',
          style: AppTextStyles.caption.copyWith(
            fontSize: 6,
            color: enabled ? Colors.black : const Color(0xFF888888),
          ),
        ),
      ),
    );
  }
}