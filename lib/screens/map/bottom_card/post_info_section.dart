import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';
import 'package:unimal/service/map/models/map_post.dart';

/// Renders title, address, relative time, content, like/reply counts,
/// and the full-width "자세히 보기" button.
///
/// [padding] should include any safe-area bottom inset when the card
/// is positioned at the bottom of the screen.
class PostInfoSection extends StatelessWidget {
  final MapPost post;
  final EdgeInsets padding;
  final bool showDetailButton;

  const PostInfoSection({
    super.key,
    required this.post,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
    this.showDetailButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 제목 + 시간
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  post.title.isNotEmpty ? post.title : '제목 없음',
                  style: const TextStyle(
                    fontSize: 17,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                relativeTimeFromString(post.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Pretendard',
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
          // 주소
          if (post.streetName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF9E9E9E)),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    post.streetName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                      color: Color(0xFF9E9E9E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          // 내용
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Pretendard',
                color: Color(0xFF9E9E9E),
                height: 1.4,
              ),
            ),
          ],
          // 좋아요 · 댓글
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.favorite, size: 16, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 4),
              Text(
                '${post.likeCount}',
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Pretendard',
                  color: Color(0xFF9E9E9E),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.chat_bubble_outline, size: 15, color: Color(0xFF4D91FF)),
              const SizedBox(width: 4),
              Text(
                '${post.replyCount}',
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Pretendard',
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
          // 자세히 보기 — 전체 너비 큰 파란 버튼
          if (showDetailButton) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Get.toNamed('/detail-board', parameters: {'id': post.id}),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4D91FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '자세히 보기',
                      style: TextStyle(
                        fontSize: 15,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
