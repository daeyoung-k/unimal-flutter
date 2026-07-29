import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';
import 'package:unimal/service/map/models/map_feed.dart';
import 'package:unimal/theme/app_colors.dart';
import 'package:unimal/utils/display_title.dart';

/// 피드 카드 1장의 폭. 섹션 행 높이 계산과 함께 맞춰야 하므로 상수로 둔다.
const double kMapFeedCardWidth = 116;

/// 썸네일 정사각 변 = 카드 폭. 그 아래 제목 2줄 + 메타 1줄.
const double _thumbSize = kMapFeedCardWidth;

class MapFeedCard extends StatelessWidget {
  const MapFeedCard({super.key, required this.item, required this.onTap});

  final MapFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // 제목이 비면 본문 첫 줄을 제목 자리에 쓴다 (마커 캡션과 같은 규칙).
    final label = displayTitle(item.title, item.content);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: kMapFeedCardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _Thumbnail(item: item, colors: colors),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.25,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.favorite, size: 11, color: colors.textMuted),
                const SizedBox(width: 2),
                Text(
                  '${item.likeCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Pretendard',
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    relativeTimeFromString(item.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Pretendard',
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 썸네일 — 없으면(텍스트 글 / 파생 실패) 본문 스니펫 타일로 대체한다.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item, required this.colors});

  final MapFeedItem item;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final url = item.thumbnailUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: _thumbSize,
        height: _thumbSize,
        color: colors.surfaceMuted,
        padding: const EdgeInsets.all(10),
        alignment: Alignment.topLeft,
        child: Text(
          item.content,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1.35,
            fontFamily: 'Pretendard',
            color: colors.textSecondary,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: _thumbSize,
      height: _thumbSize,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        width: _thumbSize,
        height: _thumbSize,
        color: colors.surfaceVariant,
      ),
      errorWidget: (_, __, ___) => Container(
        width: _thumbSize,
        height: _thumbSize,
        color: colors.surfaceVariant,
        alignment: Alignment.center,
        child: Icon(Icons.image_not_supported_outlined,
            size: 20, color: colors.textMuted),
      ),
    );
  }
}
