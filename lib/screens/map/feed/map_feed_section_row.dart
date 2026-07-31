import 'dart:async';

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
///
/// ## 헤더 우측 새로고침 버튼 (2026-07-31)
///
/// [onRefresh] 가 있을 때만 그린다. 시트는 **모든 섹션에 넘긴다** — 서버에
/// 섹션 단건 조회(`/board/map/feed/section?type=...`)가 있어서 버튼과 갱신
/// 대상이 정확히 1:1 이기 때문이다. 눌린 섹션만 제자리에서 갈리고 나머지 섹션은
/// 건드리지 않는다 (`map_feed_sheet.dart` 의 `_refreshSection` 참고).
///
/// 이 자리를 고른 이유 — 시트 핸들 줄은 **드래그 영역**이라 버튼을 두면 시트를
/// 끌어올리려다 눌리는 오탭이 나고, peek(0.11) 에서도 그 줄만 보여 접힌 채로
/// 눌려버린다. 광고를 "펼쳐서 멎은 뒤에만" 마운트한 것과 같은 이유다.
/// 지도 상단(검색바 아래)은 갱신 대상인 시트와 화면 반대편이라, 눌러도 무엇이
/// 바뀌었는지 눈으로 쫓을 수 없다. 게다가 섹션이 여럿이면 "어느 섹션을
/// 새로고침하는 버튼인지"가 아예 표현되지 않는다.
class MapFeedSectionRow extends StatelessWidget {
  const MapFeedSectionRow({
    super.key,
    required this.section,
    required this.onItemTap,
    this.onRefresh,
    this.isRefreshing = false,
    this.revision = 0,
  });

  final MapFeedSection section;
  final void Function(MapFeedItem item) onItemTap;

  /// null 이면 헤더에 버튼을 그리지 않는다.
  final VoidCallback? onRefresh;

  /// **이 섹션이** 조회 중이면 아이콘이 회전하고 탭은 무시된다.
  /// 다른 섹션이 도는 것과는 무관하다 — 섹션별 요청은 서로 독립이다.
  final bool isRefreshing;

  /// 이 섹션이 새로고침된 횟수. **캐러셀 위젯 key 에만 쓴다.**
  ///
  /// 값이 바뀌면 가로 `ListView` 가 새로 만들어져 스크롤이 맨 앞으로 돌아간다.
  /// 오른쪽으로 넘겨본 상태에서 새로고침하면 카드만 갈리고 위치는 그대로라,
  /// 앞쪽에 새로 온 글을 못 보고 "안 바뀌었네"로 읽히기 때문이다.
  ///
  /// **바깥 위젯의 key 에 섞지 않는 이유** — 그러면 이 위젯 전체가 재생성되면서
  /// [_FeedRefreshButton] 의 State 도 같이 버려져, 응답이 도착한 순간 회전이
  /// 0도로 튀었다가 다시 도는 것처럼 보인다.
  final int revision;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final refresh = onRefresh;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // 버튼이 붙는 쪽 우측 여백은 12 — 아이콘의 시각적 무게중심이 원 안쪽에
          // 있어 16 을 그대로 두면 오히려 더 들어가 보인다.
          padding: EdgeInsets.fromLTRB(16, 0, refresh == null ? 16 : 12, 8),
          child: Row(
            children: [
              _SectionBadge(type: section.type),
              const SizedBox(width: 7),
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
              if (refresh != null)
                _FeedRefreshButton(
                  key: mapFeedRefreshButtonKey(section.type),
                  onTap: refresh,
                  isRefreshing: isRefreshing,
                ),
            ],
          ),
        ),
        SizedBox(
          height: kMapFeedRowHeight,
          child: ListView.separated(
            // key 가 바뀌면 스크롤이 맨 앞으로 돌아간다 ([revision] 주석 참고).
            key: ValueKey('carousel-${section.type.name}#$revision'),
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

/// 섹션 헤더 좌측의 타입 뱃지.
///
/// 섹션이 셋으로 늘면 **헤더가 전부 같은 15pt 볼드 텍스트라 훑을 때 경계가 안
/// 걸린다.** 카드(96pt 썸네일)의 시각적 무게가 훨씬 커서 헤더가 묻히기 때문이다.
/// 색+모양이 다른 뱃지를 왼쪽에 두면 문구를 읽기 전에 섹션이 바뀐 걸 안다.
///
/// 오른쪽 ↻ 와 좌우로 균형을 이루는 효과도 있다 — 뱃지가 없으면 헤더 줄의 무게가
/// 반복되는 ↻ 때문에 우측으로만 쏠린다.
///
/// **[MapFeedSection.title] 은 서버가 내려준다.** 뱃지는 [MapFeedSectionType] 으로만
/// 정하므로 서버가 문구를 바꿔도 아이콘은 그대로다 — 문구와 아이콘이 어긋날 걱정이
/// 없고, 새 섹션 타입이 생기면 아래 switch 가 컴파일 에러로 알려준다.
class _SectionBadge extends StatelessWidget {
  const _SectionBadge({required this.type});

  final MapFeedSectionType type;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (icon, color) = switch (type) {
      // 시계 — "언제"가 기준인 섹션.
      MapFeedSectionType.latest => (Icons.schedule_rounded, colors.accentGreen),
      // 불꽃 — 반응이 기준인 섹션.
      MapFeedSectionType.hot =>
        (Icons.local_fire_department_rounded, colors.accent),
      // 위치핀 — "어디"가 기준인 섹션. 브랜드 파랑을 써서 지도 마커와 같은 계열로 읽힌다.
      MapFeedSectionType.near ||
      MapFeedSectionType.nearby =>
        (Icons.place_rounded, colors.primaryStrong),
    };

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        // 배경은 아이콘 색을 옅게 깐다. 고정 회색을 쓰면 다크모드에서 뱃지가 죽고,
        // 타입별 색 구분도 아이콘 하나에만 의존하게 된다.
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 12, color: color),
    );
  }
}

/// 위젯 테스트가 아이콘 종류에 의존하지 않고 버튼을 집을 수 있게 하는 키.
///
/// **섹션별로 달라야 한다.** 섹션마다 버튼이 하나씩 있으므로 같은 키를 쓰면
/// `find.byKey` 가 여러 개를 물어 테스트에서 어느 섹션을 누르는지 지정할 수 없다.
/// (런타임에는 서로 다른 부모 아래라 중복이어도 예외가 나지는 않는다 — 테스트만
/// 못 쓰게 된다. 그래서 더 조용히 놓치기 쉽다.)
Key mapFeedRefreshButtonKey(MapFeedSectionType type) =>
    ValueKey('map-feed-refresh-${type.name}');

/// 헤더 우측 새로고침 버튼.
///
/// 34x34 는 Material 권장 탭 타깃(48)보다 작다. 헤더 한 줄 안에 들어가야 하고
/// 목록의 보조 동작이라 이 크기로 둔다 — 대신 [InkWell] 이 아니라 원형 배경까지
/// 전체가 눌리게 해서 실제 히트 영역은 시각 크기와 같다.
///
/// `IconButton` 을 쓰지 않는 이유: 최소 크기 48 과 기본 패딩이 강제라 헤더 높이가
/// 그만큼 밀린다.
class _FeedRefreshButton extends StatefulWidget {
  const _FeedRefreshButton({
    super.key,
    required this.onTap,
    required this.isRefreshing,
  });

  final VoidCallback onTap;
  final bool isRefreshing;

  @override
  State<_FeedRefreshButton> createState() => _FeedRefreshButtonState();
}

class _FeedRefreshButtonState extends State<_FeedRefreshButton>
    with SingleTickerProviderStateMixin {
  static const Duration _turnDuration = Duration(milliseconds: 900);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: _turnDuration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.isRefreshing) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant _FeedRefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing == oldWidget.isRefreshing) return;
    if (widget.isRefreshing) {
      _spin.repeat();
    } else {
      unawaited(_settle());
    }
  }

  /// 응답이 즉시 와도 회전이 어중간한 각도에서 뚝 끊기지 않게, **돌던 바퀴는
  /// 마저 돌고** 멈춘다. 남은 각도에 비례한 시간만 쓰므로 체감 지연은 최대 0.9초다.
  Future<void> _settle() async {
    final remaining = 1.0 - _spin.value;
    if (remaining < 0.02) {
      _spin.value = 0;
      return;
    }
    await _spin.animateTo(
      1.0,
      duration: _turnDuration * remaining,
      curve: Curves.easeOut,
    );
    // 도중에 다시 새로고침이 시작됐으면 그 회전을 건드리지 않는다.
    if (mounted && !widget.isRefreshing) _spin.value = 0;
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      label: '피드 새로고침',
      child: Material(
        color: colors.surfaceMuted,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // 조회 중에는 탭을 막는다. 시트 쪽 `_isLoading` 가드와 중복이지만,
          // 눌러도 아무 일이 없는 것보다 눌리지 않는 편이 사용자에게 정직하다.
          onTap: widget.isRefreshing ? null : widget.onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: RotationTransition(
                turns: _spin,
                child: Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: colors.primaryStrong,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
