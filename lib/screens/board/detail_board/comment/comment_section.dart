import 'package:flutter/material.dart';
import 'package:unimal/screens/board/detail_board/comment/comment_item.dart';

class CommentSection extends StatelessWidget {
  final List<Map<String, dynamic>> comments;
  final Function(int) onDelete;

  const CommentSection({
    super.key, 
    required this.comments,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
          ...comments.map((comment) => CommentItem(
                comment: comment,
                onDelete: () => onDelete(comment['id'] as int),
              )),
        ],
      ),
    );
  }
}