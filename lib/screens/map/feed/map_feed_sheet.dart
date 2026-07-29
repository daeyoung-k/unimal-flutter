import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unimal/screens/map/feed/map_feed_section_row.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/map/models/map_feed.dart';
import 'package:unimal/theme/app_colors.dart';

/// 시트 peek 크기 — 화면 높이 대비 비율. **하한이자 초기값이다.**
/// 사용자가 시트를 완전히 없앨 수는 없다(상시 노출이 이 기능의 전제).
const double kMapFeedPeekSize = 0.15;
const double _kMaxSize = 0.9;

/// "펼쳐져 있음" 판정 임계값. peek 보다 약간 크게 둬서 스냅 애니메이션 도중의
/// 중간값이 "펼쳐짐"으로 오판되지 않게 한다.
const double _kExpandedThreshold = kMapFeedPeekSize + 0.05;

/// 피드 조회 좌표/줌. `map_naver` 가 마커 재조회 성공 시점에 갱신한다.
///
/// `==` 를 구현해야 같은 좌표로 알림이 와도 중복 조회하지 않는다.
@immutable
class MapFeedQuery {
  const MapFeedQuery({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final double latitude;
  final double longitude;
  final int zoom;

  @override
  bool operator ==(Object other) =>
      other is MapFeedQuery &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(latitude, longitude, zoom);
}

/// 메인 지도 하단 상시 피드 시트.
///
/// **데이터를 스스로 소유한다.** `map_naver.dart` 가 이미 2,900줄이라 상태를 더
/// 얹지 않기 위한 결정이다(설계 §3). `map_naver` 는 [query] 갱신과
/// [controller] 보유만 한다.
///
/// 섹션이 하나도 없으면(빈 결과·조회 실패·서버 미구현) **아무것도 렌더하지
/// 않는다.** peek 은 "올릴 게 있다"는 신호이므로 올릴 게 없으면 없는 것이 맞다.
class MapFeedSheet extends StatefulWidget {
  const MapFeedSheet({
    super.key,
    required this.query,
    required this.controller,
    required this.onItemTap,
    this.fetcher,
  });

  final ValueListenable<MapFeedQuery?> query;

  /// 마커 탭 시 외부에서 접어야 하므로 컨트롤러는 부모가 소유한다.
  final DraggableScrollableController controller;

  final void Function(MapFeedItem item) onItemTap;

  /// 피드 조회 함수. 기본값은 실제 API 호출.
  ///
  /// 테스트가 게이팅 로직(내용 없을 때 우회 / 펼쳤을 때만 갱신 / 같은 쿼리 스킵)을
  /// dotenv 초기화 없이 검증할 수 있도록 이음새를 둔다.
  final Future<MapFeedResponse?> Function(MapFeedQuery query)? fetcher;

  @override
  State<MapFeedSheet> createState() => _MapFeedSheetState();
}

class _MapFeedSheetState extends State<MapFeedSheet> {
  MapFeedResponse? _feed;
  MapFeedQuery? _loadedQuery;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    widget.query.addListener(_onQueryChanged);
    // 화면 진입 시 이미 값이 들어와 있을 수 있다.
    _onQueryChanged();
  }

  @override
  void dispose() {
    widget.query.removeListener(_onQueryChanged);
    super.dispose();
  }

  /// 컨트롤러가 시트에 붙기 전에는 `size` 가 던진다 — 그 경우 접힌 것으로 본다.
  bool get _isExpanded {
    try {
      return widget.controller.size > _kExpandedThreshold;
    } catch (_) {
      return false;
    }
  }

  /// 아직 보여줄 내용이 없는 상태.
  ///
  /// 이때는 시트가 렌더되지 않아(`build` 가 `SizedBox.shrink`) 컨트롤러가 부착되지
  /// 않고, 따라서 [_isExpanded] 가 영원히 false 다. 즉 **사용자가 시트를 펼칠 수단
  /// 자체가 없다.** 그래서 내용이 없는 동안은 peek 게이트를 우회해 계속 조회한다.
  /// (첫 조회 실패가 피드를 영구히 죽이던 버그 — 2026-07-29)
  bool get _hasContent => _feed?.sections.isNotEmpty ?? false;

  void _onQueryChanged() {
    final query = widget.query.value;
    if (query == null) return;

    // 보여줄 내용이 없으면 펼침 여부와 무관하게 조회한다 (위 주석 참고).
    if (!_hasContent) {
      unawaited(_fetch(query));
      return;
    }
    // 내용이 있는 뒤로는 시트가 펼쳐져 있을 때만 갱신한다 (설계 §3).
    if (!_isExpanded) return;
    if (query == _loadedQuery) return;
    unawaited(_fetch(query));
  }

  Future<void> _fetch(MapFeedQuery query) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final feed = widget.fetcher != null
        ? await widget.fetcher!(query)
        : await BoardApiService().getMapFeed(
            latitude: query.latitude,
            longitude: query.longitude,
            zoom: query.zoom,
          );
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      // 실패 시 기존 내용을 유지한다 — 깜빡임보다 묵은 데이터가 낫다.
      if (feed != null) {
        _feed = feed;
        _loadedQuery = query;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sections = _feed?.sections ?? const <MapFeedSection>[];
    // 보여줄 게 없으면 시트 자체를 만들지 않는다.
    if (sections.isEmpty) return const SizedBox.shrink();

    final colors = AppColors.of(context);

    return DraggableScrollableSheet(
      controller: widget.controller,
      initialChildSize: kMapFeedPeekSize,
      minChildSize: kMapFeedPeekSize,
      maxChildSize: _kMaxSize,
      snap: true,
      snapSizes: const [kMapFeedPeekSize, _kMaxSize],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 16,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          // 핸들을 같은 스크롤뷰 안에 둬야 핸들을 잡아도 시트가 끌린다
          // (DraggableScrollableSheet 는 controller 가 붙은 스크롤러로만 끌림 —
          //  my_story_map_screen 의 같은 주석 참고).
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              for (final section in sections) ...[
                MapFeedSectionRow(
                  section: section,
                  onItemTap: widget.onItemTap,
                ),
                const SizedBox(height: 18),
              ],
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
            ],
          ),
        );
      },
    );
  }
}
