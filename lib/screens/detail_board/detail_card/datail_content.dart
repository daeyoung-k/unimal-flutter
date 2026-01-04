import 'package:flutter/material.dart';

class DetailContent extends StatelessWidget {
  final String? title;
  final String content;
  final bool? isLike;
  final String? likeCount;
  final String? replyCount;
  
  const DetailContent({
    super.key, 
    this.title = '',
    required this.content,
    this.isLike,
    this.likeCount,
    this.replyCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
      padding: const EdgeInsets.all(12),
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
          // 제목 표시
          if (title != null && title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            
          // 콘텐츠 텍스트
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
              // 좋아요 버튼
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    (isLike ?? false) ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color: (isLike ?? false) ? Colors.red[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    likeCount ?? "0",
                    style: TextStyle(
                      fontSize: 14,
                      color: (isLike ?? false) ? Colors.red[400] : Colors.grey[600],
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // 댓글 버튼
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    replyCount ?? "0",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(
                Icons.access_time,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                '방금 전',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontFamily: 'Pretendard',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}