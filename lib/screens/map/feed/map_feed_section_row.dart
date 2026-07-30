import 'package:flutter/material.dart';
import 'package:unimal/screens/map/feed/map_feed_card.dart';
import 'package:unimal/service/map/models/map_feed.dart';
import 'package:unimal/theme/app_colors.dart';

/// 섹션 행 전체 높이 = 썸네일(116) + 간격(6) + 제목 2줄(≈32) + 간격(3) + 메타(≈14)
/// + 하단 여유. 카루셀을 `SizedBox` 로 감싸야 `ListView` 안에서 높이가 확정된다.
const double kMapFeedRowHeight = 178;

/// 섹션 1개 = 헤더(서버가 준 title) + 가로 카루셀.
///
/// ## 헤더에 `>` 를 그리지 않는다 (2026-07-30)
///
/// 예전엔 `section.hasMore` 일 때 헤더 우측에 `Icons.chevron_right` 를 띄웠는데,
/// **탭 동작이 없는 장식이었다.** 이 앱의 다른 모든 `>`(마이페이지·공지·설정·비밀지도)는
/// 전부 눌리는 버튼이라, 여기서만 반응이 없으면 사용자는 버그로 읽는다.
/// **안 눌리는 어포던스는 없는 것보다 나쁘다.**
///
/// [MapFeedSection.hasMore] 는 계속 파싱한다 — 지우지 않는다. 섹션당 노출이
/// 10장으로 줄어 "더보기"가 실제로 의미를 갖는 시점에, 이 헤더에 `GestureDetector` 와
/// 함께 되살릴 자리다. 그때는 서버에 `section`/`offset` 파라미터가 먼저 생겨야 한다.
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
