import 'package:flutter/material.dart';
import 'package:unimal/screens/map/feed/map_feed_card.dart';
import 'package:unimal/service/map/models/map_feed.dart';
import 'package:unimal/theme/app_colors.dart';

/// 섹션 행 전체 높이 = 썸네일(116) + 간격(6) + 제목 2줄(≈32) + 간격(3) + 메타(≈14)
/// + 하단 여유. 카루셀을 `SizedBox` 로 감싸야 `ListView` 안에서 높이가 확정된다.
const double kMapFeedRowHeight = 178;

/// 섹션 1개 = 헤더(서버가 준 title) + 가로 카루셀.
///
/// `hasMore` 면 헤더에 `>` 만 표시한다. **탭 동작은 없다** — 섹션별 더보기
/// 페이지네이션은 서버 스펙에서도 범위 밖이다.
class MapFeedSectionRow extends StatelessWidget {
  const MapFeedSectionRow({
    super.key,
    required this.section,
    required this.onItemTap,
  });

  final MapFeedSection section;
  final void Function(MapFeedItem item) onItemTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (section.hasMore)
                Icon(Icons.chevron_right,
                    size: 20, color: colors.textMuted),
            ],
          ),
        ),
        SizedBox(
          height: kMapFeedRowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: section.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final item = section.items[i];
              return MapFeedCard(
                item: item,
                onTap: () => onItemTap(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
