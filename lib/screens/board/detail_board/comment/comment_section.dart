import 'package:flutter/material.dart';
import 'package:unimal/screens/board/detail_board/comment/comment_item.dart';

class CommentSection extends StatelessWidget {
  final List<Map<String, dynamic>> comments;
  final Function(String) onDelete;
  final Function(String, String) onEdit;
  final Function(String, String) onReply;

  const CommentSection({
    super.key,
    required this.comments,
    required this.onDelete,
    required this.onEdit,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final topLevel = comments
        .where((c) => (c['parentId'] as String? ?? '').isEmpty)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 댓글 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  Text(
                    '댓글 ${comments.length}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            if (comments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Text(
                    '아직 댓글이 없어요.\n첫 번째 댓글을 남겨보세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                      height: 1.6,
                    ),
                  ),
                ),
              )
            else
              ...topLevel.expand((parent) {
                final children = comments
                    .where((c) => (c['parentId'] as String? ?? '') == parent['id'])
                    .toList();
                return [
                  CommentItem(
                    comment: parent,
                    onDelete: () => onDelete(parent['id'] as String),
                    onEdit: () => onEdit(parent['id'] as String, parent['content'] as String),
                    onReply: () => onReply(parent['id'] as String, parent['author'] as String),
                  ),
                  ...children.map((child) => CommentItem(
                        comment: child,
                        isNested: true,
                        onDelete: () => onDelete(child['id'] as String),
                        onEdit: () => onEdit(child['id'] as String, child['content'] as String),
                        onReply: null,
                      )),
                  if (children.isNotEmpty)
                    _ThreadReplyButton(
                      onTap: () => onReply(parent['id'] as String, parent['author'] as String),
                    ),
                ];
              }),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _ThreadReplyButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ThreadReplyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFF),
      padding: const EdgeInsets.only(left: 68, top: 4, bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.reply_rounded, size: 14, color: Color(0xFF7AB3FF)),
            const SizedBox(width: 4),
            const Text(
              '답글 달기',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                color: Color(0xFF7AB3FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
