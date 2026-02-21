import 'package:flutter/material.dart';
import 'package:unimal/screens/board/detail_board/comment/comment_item.dart';

class CommentSection extends StatelessWidget {
  final List<Map<String, dynamic>> comments;
  final Function(String) onDelete;
  final Function(String, String) onEdit;
  final Function(String, String) onReply; // (replyId, nickname)

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

    if (comments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '아직 댓글이 없습니다.\n첫 번째 댓글을 남겨보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  '댓글 ${comments.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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
              // 대댓글이 있을 때만 스레드 하단 답글 버튼 표시
              if (children.isNotEmpty)
                _ThreadReplyButton(
                  onTap: () => onReply(parent['id'] as String, parent['author'] as String),
                ),
            ];
          }),
        ],
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
      color: const Color(0xFFF7F9FF),
      padding: const EdgeInsets.only(left: 52, top: 4, bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(Icons.reply, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              '답글 달기',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
