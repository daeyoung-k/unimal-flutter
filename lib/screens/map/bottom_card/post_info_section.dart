import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';
import 'package:unimal/service/map/models/map_post.dart';
import 'package:unimal/theme/app_colors.dart';

/// Renders title, address, relative time, content, like/reply counts,
/// and the full-width "자세히 보기" button.
///
/// [padding] should include any safe-area bottom inset when the card
/// is positioned at the bottom of the screen.
class PostInfoSection extends StatelessWidget {
  final MapPost post;
  final EdgeInsets padding;
  final bool showDetailButton;
  final int contentMaxLines;

  /// 좋아요 토글 핸들러. 좋아요 아이콘/숫자 탭 시 호출.
  final VoidCallback? onLikeTap;

  /// 댓글 아이콘/숫자 탭 시 호출 (카드 확장).
  final VoidCallback? onReplyTap;

  /// 본문이 [contentMaxLines]를 넘었을 때 노출되는 "더보기" 링크의 탭 핸들러.
  /// null이면 더보기 자체를 숨김(peek 카드).
  final VoidCallback? onShowMore;

  /// 수정 아이콘 탭 핸들러. null이면 수정 버튼 숨김.
  final VoidCallback? onEditTap;

  /// 좋아요 활성 상태. null이면 미설정(회색 outline).
  final bool isLiked;

  /// 외부에서 override한 좋아요 수. null이면 post.likeCount 사용.
  final int? likeCountOverride;

  const PostInfoSection({
    super.key,
    required this.post,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
    this.showDetailButton = true,
    this.contentMaxLines = 2,
    this.onLikeTap,
    this.onReplyTap,
    this.onShowMore,
    this.onEditTap,
    this.isLiked = false,
    this.likeCountOverride,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
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
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dummyStreetName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(Icons.location_on_outlined,
                                  size: 13, color: colors.textTertiary),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                dummyStreetName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Pretendard',
                                  color: colors.textTertiary,
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
                // 날짜 + 수정 버튼 (내 글일 때)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      relativeTimeFromString(post.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Pretendard',
                        color: colors.textTertiary,
                      ),
                    ),
                    if (onEditTap != null) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onEditTap,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.edit_outlined,
                              size: 13, color: colors.primaryStrong),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          }),
          // 타이틀 — 비어 있으면 행 자체를 숨긴다 (본문 첫 줄이 타이틀 역할).
          if (post.title.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              post.title,
              style: TextStyle(
                fontSize: 17,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // 내용 — contentMaxLines 초과 시 마지막 줄 우측에 "더보기" 오버레이.
          // Stack을 쓰는 이유: 별도 row를 추가하면 카드 영역을 넘어 overflow 발생.
          if (post.content.isNotEmpty) ...[
            SizedBox(height: post.title.isNotEmpty ? 6 : 14),
            // 본문을 Expanded로 채워 좋아요 행을 카드 바닥에 고정하고, 공간이 부족하면
            // 본문이 잘리도록 한다. (고정 높이 추정(_infoSectionReserved)이 빗나가도
            // overflow 줄무늬 대신 본문이 흡수 — Stack 기본 clip이 넘친 텍스트를 잘라줌)
            Expanded(
              child: Builder(builder: (context) {
              final contentStyle = TextStyle(
                fontSize: 14,
                fontFamily: 'Pretendard',
                color: colors.textPrimary,
                height: 1.4,
              );
              return LayoutBuilder(builder: (context, constraints) {
                final tp = TextPainter(
                  text: TextSpan(text: post.content, style: contentStyle),
                  textDirection: TextDirection.ltr,
                  maxLines: contentMaxLines,
                )..layout(maxWidth: constraints.maxWidth);
                final overflows = tp.didExceedMaxLines;
                tp.dispose();
                return SizedBox(
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Text(
                        post.content,
                        maxLines: contentMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: contentStyle,
                      ),
                      if (overflows && onShowMore != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onShowMore,
                          child: Container(
                            padding: const EdgeInsets.only(left: 24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colors.surface.withValues(alpha: 0),
                                  colors.surface,
                                ],
                                stops: const [0, 0.3],
                              ),
                            ),
                            child: Text(
                              '더보기',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600,
                                color: colors.primaryStrong,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              });
            }),
            ),
          ],
          // 본문이 없을 때만 Spacer로 좋아요 행을 바닥에 고정.
          // (본문이 있으면 위 Expanded가 공간을 채우므로 Spacer 불필요)
          if (post.content.isEmpty) const Spacer(),
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
                      color: isLiked ? colors.danger : colors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${likeCountOverride ?? post.likeCount}',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        color: colors.textTertiary,
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
                    Icon(Icons.chat_bubble_outline,
                        size: 15, color: colors.primaryStrong),
                    const SizedBox(width: 4),
                    Text(
                      '${post.replyCount}',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        color: colors.textTertiary,
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
                  backgroundColor: colors.primaryStrong,
                  foregroundColor: colors.surface,
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
    final colors = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceVariant,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
          : Icon(Icons.person_outline,
              size: size * 0.55, color: colors.textMuted),
    );
  }
}
