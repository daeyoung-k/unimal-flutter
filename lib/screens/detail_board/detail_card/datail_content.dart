import 'package:flutter/material.dart';

class DetailContent extends StatelessWidget {
  final String content;
  final String likeCount;
  final String commentCount;

  const DetailContent({
    super.key, 
    required this.content,
    required this.likeCount,
    required this.commentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            content.isEmpty ? '내용이 없습니다.' : content,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              color: Color(0xFF2C3E50),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.favorite, size: 16, color: Colors.red[400]),
              const SizedBox(width: 6),
              Text(
                likeCount,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[400],
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 14),
              Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                commentCount,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.share_outlined, size: 16, color: Colors.grey[600]),
            ],
          ),
        ],
      ),
    );
  }
}