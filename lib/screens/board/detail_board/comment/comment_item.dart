import 'package:flutter/material.dart';

class CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onReply;
  final bool isNested;

  const CommentItem({
    super.key,
    required this.comment,
    required this.onDelete,
    required this.onEdit,
    this.onReply,
    this.isNested = false,
  });

  Widget _buildAvatar(double size) {
    final author = comment['author'] as String? ?? '?';
    final letter = author.isNotEmpty ? author[0] : '?';
    final url = comment['profileImageUrl'] as String?;

    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(isNested ? 8 : 10),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialAvatar(letter, size),
        ),
      );
    }
    return _buildInitialAvatar(letter, size);
  }

  Widget _buildInitialAvatar(String letter, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9AC5FF), Color(0xFF7AB3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isNested ? 8 : 10),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return '방금 전';
    if (difference.inHours < 1) return '${difference.inMinutes}분 전';
    if (difference.inDays < 1) return '${difference.inHours}시간 전';
    if (difference.inDays < 7) return '${difference.inDays}일 전';
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final double avatarSize = isNested ? 30.0 : 38.0;

    return Container(
      color: isNested ? const Color(0xFFF8FAFF) : Colors.transparent,
      padding: EdgeInsets.only(left: isNested ? 24 : 0),
      child: Column(
        children: [
          if (isNested)
            Divider(height: 1, indent: 24, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNested) ...[
                  Icon(Icons.subdirectory_arrow_right, size: 14, color: Colors.grey[300]),
                  const SizedBox(width: 4),
                ],
                _buildAvatar(avatarSize),
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
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(comment['createdAt'] as DateTime),
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        comment['content'] as String,
                        style: TextStyle(
                          fontSize: isNested ? 13 : 14,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF374151),
                          height: 1.5,
                        ),
                      ),
                      if (onReply != null) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: onReply,
                          child: const Text(
                            '답글 달기',
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7AB3FF),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (comment['isOwner'] as bool? ?? false)
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (context) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 36, height: 4,
                                margin: const EdgeInsets.only(top: 12, bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              ListTile(
                                leading: Icon(Icons.edit_outlined, color: Colors.grey[700], size: 20),
                                title: Text('수정', style: TextStyle(fontFamily: 'Pretendard', color: Colors.grey[800], fontWeight: FontWeight.w500)),
                                onTap: () { Navigator.pop(context); onEdit(); },
                              ),
                              ListTile(
                                leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                title: const Text('삭제', style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFFEF4444), fontWeight: FontWeight.w500)),
                                onTap: () { Navigator.pop(context); onDelete(); },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.more_vert, size: 18, color: Color(0xFF7AB3FF)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
