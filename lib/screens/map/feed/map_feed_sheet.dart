import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unimal/screens/map/feed/map_feed_section_row.dart';
import 'package:unimal/service/ads/ad_banner.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/map/models/map_feed.dart';
import 'package:unimal/theme/app_colors.dart';

/// 시트 peek 크기 — 화면 높이 대비 비율. **하한이자 초기값이다.**
/// 사용자가 시트를 완전히 없앨 수는 없다(상시 노출이 이 기능의 전제).
///
/// 2026-07-30: 0.15 → 0.11 로 낮춤(사용자 요청 — "좀 더 내려달라"). `map_naver.dart`
/// 의 `bottomButtonOffset` 이 이 값으로 계산되는데, `bottomButtonBase = 45` 보다
/// 작아지면 버튼이 오히려 더 내려가는 역전이 생긴다. `bottomButtonOffset` 계산에
/// `max(bottomButtonBase, ...)`(`dart:math`) 를 이미 씌워뒀으니 역전 자체는 코드로도
/// 막혀 있다 — 그래도 값이 튀지 않는지는 이 주석에서 재확인할 것.
///
/// 2026-07-31: 광고를 붙이면서 0.12 로 올렸다가 0.11 로 되돌렸다. 접힌 상태에서는
/// 광고를 아예 렌더하지 않기로 해서(아래 [_kExpandedThreshold] 참고) peek 높이에
/// 광고가 들어갈 필요가 없어졌다.
const double kMapFeedPeekSize = 0.11;

/// 중간 스냅. 핸들(28pt) + 광고 + 섹션 1개(약 238pt) 가 들어가는 높이.
///
/// 2026-07-31: 섹션 헤더에 새로고침 버튼(34pt)이 들어가며 헤더 줄이 20 → 34pt 로
/// 커져 섹션 높이가 224 → 238 이 됐다. 시트는 스크롤되므로 넘쳐도 잘리지 않는다.
///
/// 어댑티브 배너 높이는 기기 화면 높이에 따라 32/50/90pt 로 달라져 한 값으로 딱
/// 맞출 수는 없다. 시트는 어차피 스크롤되므로 "적당히 편한 중간"으로 잡는다.
///   iPhone 14 (844) → 380pt
///   iPhone SE (667) → 300pt
const double _kMidSize = 0.45;
const double _kMaxSize = 0.9;

/// "펼쳐져 있음" 판정 임계값. peek 보다 약간 크게 둬서 스냅 애니메이션 도중의
/// 중간값이 "펼쳐짐"으로 오판되지 않게 한다.
const double _kExpandedThreshold = kMapFeedPeekSize + 0.05;

/// 섹션 구분자의 위/아래 여백 (헤어라인 기준 한쪽). 총 간격은 `28 + 1 + 28`.
///
/// 카드 사이 간격이 10 이므로 그 3배 가까이 벌려야 "다른 묶음"으로 읽힌다
/// (`_sectionSeparator` 주석 참고). 섹션 간 여백을 조절할 유일한 손잡이다.
const double _kSectionGap = 28;

/// 시트가 멎고 나서 광고를 붙이기까지의 여유.
///
/// `AdWidget` 은 네이티브 플랫폼 뷰라 생성 비용이 크다. 드래그·스냅이 진행되는
/// 동안 붙이면 그 프레임이 통째로 떨어져 시트가 툭툭 끊긴다. 움직임이 멎은 뒤에
/// 붙이면 사용자는 광고가 "뒤늦게 스르륵 나타나는" 것으로만 인지한다.
/// `map_naver` 의 시트 애니메이션이 220ms 라 그보다 살짝 길게 잡았다.
const Duration _kAdSettleDelay = Duration(milliseconds: 260);

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
    this.sectionFetcher,
    this.onContentChanged,
    this.adBuilder,
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

  /// 섹션 단건 조회 함수. 기본값은 실제 API 호출. ([fetcher] 와 같은 이유의 이음새)
  final Future<MapFeedSectionResult> Function(
    MapFeedQuery query,
    MapFeedSectionType type,
  )? sectionFetcher;

  /// 시트가 보여줄 내용을 갖게 되었는지 부모에게 알린다.
  ///
  /// 섹션이 없으면 시트는 아예 렌더되지 않는데(`build` 가 `SizedBox.shrink`),
  /// 부모는 그 사실을 알 수 없어 시트가 있다고 가정한 레이아웃(하단 버튼 위치)을
  /// 그대로 유지한다. 서버 미구현 기간에는 영구히 내용이 없으므로, 부모가 이를
  /// 알아야 버튼이 허공에 뜨지 않는다.
  final ValueChanged<bool>? onContentChanged;

  /// 광고 슬롯 빌더. 기본값은 실제 애드몹 고정 배너.
  ///
  /// 위젯 테스트가 AdMob SDK 초기화 없이 클릭 게이팅을 검증할 수 있도록 이음새를 둔다.
  /// ([fetcher] 와 같은 이유)
  final WidgetBuilder? adBuilder;

  @override
  State<MapFeedSheet> createState() => _MapFeedSheetState();
}

class _MapFeedSheetState extends State<MapFeedSheet> {
  MapFeedResponse? _feed;
  MapFeedQuery? _loadedQuery;
  bool _isLoading = false;

  /// 지금 사용자가 새로고침 중인 섹션들. 아이콘 회전·버튼 비활성에 쓴다.
  ///
  /// **Set 인 이유** — 섹션마다 요청이 독립이고 각자 자기 섹션만 교체하므로, 서로
  /// 다른 섹션을 동시에 새로고침해도 안전하다. 하나가 도는 동안 나머지 버튼까지
  /// 막으면 부분 갱신을 만든 의미가 없다. 같은 섹션 연타만 [_refreshSection] 이 막는다.
  ///
  /// 자동 갱신([_fetch])은 여기에 들어오지 않는다 — 사용자가 누르지 않았는데
  /// 30초마다 아이콘이 도는 건 노이즈다.
  final Set<MapFeedSectionType> _refreshingSections = <MapFeedSectionType>{};

  /// 섹션별 갱신 횟수. [MapFeedSectionRow.revision] 으로 내려가 **새로고침한
  /// 섹션의 캐러셀을 맨 앞으로 되돌린다** (자세한 이유는 그쪽 주석 참고).
  final Map<MapFeedSectionType, int> _sectionRevisions =
      <MapFeedSectionType, int>{};

  /// 시트가 펼쳐져 있는지. 드래그 중 매 프레임 바뀌므로 setState 대신 notifier 로 둬서
  /// 광고 슬롯만 다시 그린다 (시트 전체를 재빌드하면 스크롤이 버벅인다).
  final ValueNotifier<bool> _expandedNotifier = ValueNotifier<bool>(false);

  /// 광고를 실제로 트리에 붙일지. [_expandedNotifier] 와 분리한 이유는
  /// **펼쳐진 직후가 아니라 시트가 멎은 뒤에** 붙이기 위해서다([_kAdSettleDelay]).
  final ValueNotifier<bool> _adMountedNotifier = ValueNotifier<bool>(false);
  Timer? _adSettleTimer;

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
    _adSettleTimer?.cancel();
    _expandedNotifier.dispose();
    _adMountedNotifier.dispose();
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

  /// 섹션 헤더의 ↻ 버튼. **그 섹션만** 다시 받아 제자리에 갈아끼운다.
  ///
  /// 서버는 섹션 하나를 요청받아도 내부에서 전체 피드를 계산한다 — 섹션들이 하나의
  /// 후보 풀을 `NEAR → HOT → LATEST` 순으로 나눠 갖는 구조라 서로 독립이 아니기
  /// 때문이다. 덕분에 **부분 갱신 결과가 전체 조회 결과와 어긋나지 않는다**
  /// (같은 글이 두 섹션에 겹쳐 뜨는 일이 없다).
  ///
  /// 요청에는 `refresh=true` 가 실린다 — 서버 응답 캐시가 60초라 이걸 안 보내면
  /// 같은 자리에서 1분간 직전과 똑같은 데이터가 돌아와 버튼이 고장난 것처럼 보인다.
  Future<void> _refreshSection(MapFeedSectionType type) async {
    final query = widget.query.value;
    if (query == null) return;
    // 같은 섹션 연타만 막는다. 다른 섹션은 동시에 돌아도 서로 간섭하지 않는다.
    if (_refreshingSections.contains(type)) return;

    setState(() => _refreshingSections.add(type));
    try {
      final result = widget.sectionFetcher != null
          ? await widget.sectionFetcher!(query, type)
          : await BoardApiService().getMapFeedSection(
              latitude: query.latitude,
              longitude: query.longitude,
              zoom: query.zoom,
              type: type,
            );
      if (!mounted) return;

      // 통신/파싱 실패면 화면을 그대로 둔다. "그 섹션이 지금 없음"(성공 + null)
      // 과 구분해야 잠깐의 오류에 멀쩡한 섹션이 사라지지 않는다.
      if (!result.isSuccess) return;

      // `_feed` 는 await 뒤에 다시 읽는다 — 대기 중에 자동 갱신이 통째로 갈아끼웠을
      // 수 있다. 그 경우 아래 [_applySection] 이 해당 type 을 못 찾아 아무것도 하지
      // 않는데, 이미 더 최신 데이터로 덮인 뒤이므로 그대로 두는 것이 맞다.
      final current = _feed;
      if (current == null) return;

      final hadContent = _hasContent;
      setState(() {
        _feed = _applySection(current, type, result.section);
        _sectionRevisions[type] = (_sectionRevisions[type] ?? 0) + 1;
      });
      if (_hasContent != hadContent) {
        widget.onContentChanged?.call(_hasContent);
      }
    } finally {
      if (mounted) setState(() => _refreshingSections.remove(type));
    }
  }

  /// 섹션 사이 구분자 — 여백 + 헤어라인 + 여백.
  ///
  /// 개정 전에는 섹션마다 `SizedBox(height: 18)` 하나였는데, 그건 **카드 사이
  /// 간격(10)의 두 배도 안 돼서 섹션 경계가 카드 경계와 비슷한 무게로 읽혔다.**
  /// 근접성만으로 묶으려면 안쪽 간격보다 확실히 커야 한다.
  ///
  /// 배경색 교대(zebra)나 굵은 구분선은 쓰지 않는다. 시트가 이미 흰 표면이고 그 위에
  /// 광고 배너 블록까지 있어서, 색 블록을 더 얹으면 화면이 조각조각 나뉜다.
  /// 1px 헤어라인이면 "여기서 끊긴다"는 신호로 충분하다.
  ///
  /// 간격을 조절할 일이 생기면 [_kSectionGap] 하나만 만지면 된다.
  Widget _sectionSeparator(AppColors colors) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: _kSectionGap),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: colors.divider,
          ),
          const SizedBox(height: _kSectionGap),
        ],
      );

  /// [type] 섹션을 **제자리에서** 교체한다. [updated] 가 null 이면 그 자리를 없앤다.
  ///
  /// 자리를 유지하는 게 핵심이다. 지우고 뒤에 붙이면 서버의 표시 순서
  /// (`FeedSectionType` 선언 순서)와 어긋나 새로고침할 때마다 섹션이 위아래로 뛴다.
  ///
  /// [updated] 가 null 인 경우는 적응형 섹션이 조건을 못 채워 사라진 정상 상황이다.
  /// 마지막 섹션까지 사라지면 `sections` 가 비어 시트가 렌더되지 않는데, 그러면
  /// [_hasContent] 가 false 가 되어 [_onQueryChanged] 의 "내용 없으면 무조건 조회"
  /// 경로로 자연 복구된다.
  MapFeedResponse _applySection(
    MapFeedResponse current,
    MapFeedSectionType type,
    MapFeedSection? updated,
  ) {
    final sections = <MapFeedSection>[];
    for (final section in current.sections) {
      if (section.type != type) {
        sections.add(section);
      } else if (updated != null) {
        sections.add(updated);
      }
    }
    return MapFeedResponse(dong: current.dong, sections: sections);
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

    final hadContent = _hasContent;
    setState(() {
      _isLoading = false;
      // 실패 시 기존 내용을 유지한다 — 깜빡임보다 묵은 데이터가 낫다.
      if (feed != null) {
        _feed = feed;
        _loadedQuery = query;
      }
    });
    if (_hasContent != hadContent) {
      widget.onContentChanged?.call(_hasContent);
    }
  }

  /// 드래그/스냅 중 매 프레임 들어온다. 값이 실제로 바뀔 때만 notifier 가 알리므로
  /// 여기서 별도 비교는 하지 않는다.
  void _onExtentChanged(double extent) {
    final expanded = extent > _kExpandedThreshold;
    _expandedNotifier.value = expanded;

    if (!expanded) {
      // 접히는 건 즉시 반영한다 — 광고가 남아 있을 이유가 없다.
      _adSettleTimer?.cancel();
      _adMountedNotifier.value = false;
      return;
    }
    if (_adMountedNotifier.value) return; // 이미 붙어 있으면 유지

    // 움직임이 멎을 때까지 타이머를 계속 미룬다.
    _adSettleTimer?.cancel();
    _adSettleTimer = Timer(_kAdSettleDelay, () {
      if (mounted) _adMountedNotifier.value = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 빈 섹션은 걸러낸다. MapFeedSectionRow 도 자체 방어가 있지만, 여기서 안 거르면
    // 구분선(_sectionSeparator)만 남아 "있지도 않은 블록"을 암시하는 유령 선이 생긴다.
    // 서버가 MIN_SECTION_SIZE 미만을 이미 걸러 내려주므로 평소엔 no-op 이다.
    final sections = (_feed?.sections ?? const <MapFeedSection>[])
        .where((s) => s.items.isNotEmpty)
        .toList();
    // 보여줄 게 없으면 시트 자체를 만들지 않는다.
    if (sections.isEmpty) return const SizedBox.shrink();

    final colors = AppColors.of(context);

    return NotificationListener<DraggableScrollableNotification>(
      // 드래그/스냅 중 매 프레임 들어온다. 광고 클릭 게이팅에만 쓰므로
      // notifier 갱신만 하고 알림은 그대로 위로 흘려보낸다(false).
      onNotification: (notification) {
        _onExtentChanged(notification.extent);
        return false;
      },
      child: DraggableScrollableSheet(
        controller: widget.controller,
        initialChildSize: kMapFeedPeekSize,
        minChildSize: kMapFeedPeekSize,
        maxChildSize: _kMaxSize,
        snap: true,
        snapSizes: const [kMapFeedPeekSize, _kMidSize, _kMaxSize],
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
                // 광고 슬롯 — 시트 최상단(핸들 바로 아래).
                ValueListenableBuilder<bool>(
                  valueListenable: _adMountedNotifier,
                  builder: (context, visible, _) => _FeedAdSlot(
                    visible: visible,
                    adBuilder: widget.adBuilder,
                  ),
                ),
                // 섹션마다 자기 헤더에 새로고침 버튼을 갖는다 — 서버에 섹션 단건
                // 조회가 있으므로 버튼과 갱신 대상이 정확히 1:1 이다.
                //
                // 바깥 key 는 **type 만**으로 안정적으로 둔다. 섹션이 사라지거나
                // 순서가 바뀌어도 Flutter 가 같은 섹션을 알아보고, 새로고침 때
                // 위젯이 통째로 재생성되지 않아 회전 애니메이션이 끊기지 않는다.
                // 캐러셀만 되감는 건 [MapFeedSectionRow.revision] 이 처리한다.
                for (final (index, section) in sections.indexed) ...[
                  // 구분자는 섹션 **사이**에만. 첫 섹션 위(광고 바로 아래)나 마지막
                  // 섹션 아래에 두면 있지도 않은 블록을 암시한다.
                  if (index > 0) _sectionSeparator(colors),
                  MapFeedSectionRow(
                    key: ValueKey('section-${section.type.name}'),
                    section: section,
                    onItemTap: widget.onItemTap,
                    onRefresh: () => _refreshSection(section.type),
                    isRefreshing: _refreshingSections.contains(section.type),
                    revision: _sectionRevisions[section.type] ?? 0,
                  ),
                ],
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 광고 슬롯. **시트가 펼쳐져 멎은 뒤에만 광고를 만든다.**
///
/// 접힌 상태에서는 위젯 자체를 만들지 않는다. 지도를 열자마자 광고부터 보이는 건
/// 첫인상이 나쁘고, 시트를 끌어올리는 동선 위에 광고가 있으면 오탭도 나기 쉽다.
/// (오탭은 사용자에게도 짜증이고 AdMob 쪽에서 무효 클릭으로 잡힐 수도 있다.)
/// "안 보이면 클릭도 안 된다"이므로 [IgnorePointer] 같은 별도 차단 장치가 필요 없다.
///
/// 부드럽게 나타나게 하려고 세 가지를 쓴다.
/// 1. 마운트 자체를 시트가 멎은 뒤로 미룬다 ([_kAdSettleDelay]) — 네이티브 뷰 생성이
///    애니메이션 프레임을 잡아먹지 않게.
/// 2. [AnimatedSize] — 광고 로드가 끝나 높이가 0에서 늘어날 때 아래 섹션이 툭 밀리지
///    않고 같이 흘러내린다.
///
/// 라운드 처리는 [ClipRRect] 가 아니라 **광고를 감싸는 컨테이너의 테두리**로 준다.
/// 플랫폼 뷰를 클리핑하면 매 프레임 saveLayer 가 떠서 비싸고, 안드로이드에서는
/// 모서리가 제대로 안 깎이는 경우도 있다.
/// 좌우 여백은 [Padding] 이 아니라 [AdBanner.inset] 이 **요청 폭 자체를 줄여서** 준다.
/// 광고는 네이티브 뷰라 나중에 감싸는 위젯으로 줄일 수 없기 때문이다.
class _FeedAdSlot extends StatelessWidget {
  const _FeedAdSlot({required this.visible, this.adBuilder});

  final bool visible;
  final WidgetBuilder? adBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !visible
          ? const SizedBox(width: double.infinity, height: 0)
          : Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: adBuilder?.call(context) ?? const AdBanner.inset(),
                ),
              ),
            ),
    );
  }
}
