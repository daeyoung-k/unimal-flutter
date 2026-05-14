import 'package:cached_network_image/cached_network_image.dart';
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

  /// 좋아요 토글 핸들러. 좋아요 아이콘/숫자 탭 시 호출.
  final VoidCallback? onLikeTap;

  /// 댓글 아이콘/숫자 탭 시 호출 (카드 확장).
  final VoidCallback? onReplyTap;

  /// 좋아요 활성 상태. null이면 미설정(회색 outline).
  final bool isLiked;

  /// 외부에서 override한 좋아요 수. null이면 post.likeCount 사용.
  final int? likeCountOverride;

  const PostInfoSection({
    super.key,
    required this.post,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
    this.showDetailButton = true,
    this.onLikeTap,
    this.onReplyTap,
    this.isLiked = false,
    this.likeCountOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더: [아바타] (닉네임 / 위치) (우측: 날짜)
          Builder(builder: (context) {
            final dummyStreetName = post.streetName;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(imageUrl: post.profileImage, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.nickname,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dummyStreetName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(Icons.location_on_outlined,
                                  size: 13, color: Color(0xFF6B7280)),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                dummyStreetName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF6B7280),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 날짜: 항상 첫 줄 우측 상단 정렬
                Text(
                  relativeTimeFromString(post.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Pretendard',
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            );
          }),
          // 타이틀
          const SizedBox(height: 14),
          Text(
            post.title.isNotEmpty ? post.title : '제목 없음',
            style: const TextStyle(
              fontSize: 17,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A2E),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // 내용
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              post.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Pretendard',
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ],
          // 좋아요 · 댓글 — 좋아요는 토글, 댓글은 확장
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onLikeTap,
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_outline,
                      size: 16,
                      color: isLiked ? const Color(0xFFFF6B6B) : const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${likeCountOverride ?? post.likeCount}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onReplyTap,
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 15, color: Color(0xFF4D91FF)),
                    const SizedBox(width: 4),
                    Text(
                      '${post.replyCount}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
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

class _Avatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const _Avatar({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF5F5F5),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
          : Icon(Icons.person_outline, size: size * 0.55, color: const Color(0xFFBBBBBB)),
    );
  }
}
