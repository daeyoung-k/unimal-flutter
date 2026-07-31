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

/// 중간 스냅. 핸들(28pt) + 광고 + 섹션 1개(약 224pt) 가 들어가는 높이.
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
    final sections = _feed?.sections ?? const <MapFeedSection>[];
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
