import 'package:flutter/material.dart';

class CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onReply; // null이면 답글 버튼 미표시 (대댓글)
  final bool isNested;

  const CommentItem({
    super.key,
    required this.comment,
    required this.onDelete,
    required this.onEdit,
    this.onReply,
    this.isNested = false,
  });

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isNested ? const Color(0xFFF7F9FF) : Colors.transparent,
      padding: EdgeInsets.only(left: isNested ? 28 : 0),
      child: Column(
        children: [
          if (isNested) const Divider(height: 1, indent: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 대댓글 화살표 아이콘
                if (isNested) ...[
                  Icon(Icons.subdirectory_arrow_right, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                ],
                CircleAvatar(
                  radius: isNested ? 14 : 18,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: NetworkImage(comment['profileImageUrl'] as String),
                  onBackgroundImageError: (e, s) {},
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            comment['author'] as String,
                            style: TextStyle(
                              fontSize: isNested ? 13 : 14,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(comment['createdAt'] as DateTime),
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        comment['content'] as String,
                        style: TextStyle(
                          fontSize: isNested ? 13 : 14,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF2C3E50),
                          height: 1.4,
                        ),
                      ),
                      // 답글 버튼 (최상위 댓글에만 표시)
                      if (onReply != null) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: onReply,
                          child: Text(
                            '답글 달기',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (comment['isOwner'] as bool? ?? false)
                  IconButton(
                    icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[400]),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: Icon(Icons.edit_outlined, color: Colors.grey[700]),
                                title: Text('수정', style: TextStyle(fontFamily: 'Pretendard', color: Colors.grey[800], fontWeight: FontWeight.w500)),
                                onTap: () {
                                  Navigator.pop(context);
                                  onEdit();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.delete_outline, color: Color(0xFFE53935)),
                                title: const Text('삭제', style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFFE53935), fontWeight: FontWeight.w500)),
                                onTap: () {
                                  Navigator.pop(context);
                                  onDelete();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
