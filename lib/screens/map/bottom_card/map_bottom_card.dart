// lib/screens/map/bottom_card/map_bottom_card.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unimal/screens/add/share_card_sheet.dart';
import 'package:unimal/screens/map/bottom_card/map_card_expanded_content.dart';
import 'package:unimal/screens/map/bottom_card/post_group_navigator.dart';
import 'package:unimal/screens/map/bottom_card/post_image_carousel.dart';
import 'package:unimal/screens/map/bottom_card/post_info_section.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';
import 'package:unimal/theme/app_colors.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/board/model/like_info.dart';
import 'package:unimal/service/map/models/map_post.dart';
import 'package:unimal/service/share/post_share.dart';

/// 카드 상태: 기본(default_) 또는 확장(expanded).
/// 닫힘은 onClose 콜백으로 부모에서 처리.
enum _CardState { default_, expanded }

/// 지도 마커 탭 시 표시되는 카드.
///
/// 제스처:
///   - 핸들 위 드래그(≥60px / 300px/s) → 확장
///   - 핸들 아래 드래그(≥60px / 300px/s) → 기본→닫힘, 확장→기본
///   - 카드 좌우 스와이프(기본 상태만, ≥60px / 300px/s) → 이전/다음 마커 (onGroupChanged)
///   - 이미지 ‹ › 탭 → 같은 게시글 사진 전환 (PostImageCarousel이 처리)
class MapBottomCard extends StatefulWidget {
  final List<List<MapPost>> groups;
  final int initialGroupIndex;

  /// 그룹 내 특정 글 페이지로 열기 (스택 원형 펼침 마커 탭).
  /// null 이면 그룹 첫 글부터. 스와이프로 인한 그룹 변경 에코와 구분하기 위해
  /// "의도 없음"을 null 로 표현한다.
  final int? initialPostIndex;
  final VoidCallback onClose;

  /// 카드가 올라갈 수 있는 화면 상단 한계 (검색바+필터 하단).
  /// map_naver.dart에서 safeAreaTop + 약 100px로 전달.
  final double minTopMargin;

  /// 사용자가 다른 그룹으로 이동했을 때 parent에 알림.
  /// (좌우 카드 스와이프) parent는 카메라 이동 + 마커 하이라이트 + 스트립 위치 갱신을 처리한다.
  final ValueChanged<int>? onGroupChanged;

  /// 페이지(글) 이동 시 parent에 알림 — 같은 그룹 안 이동 포함.
  /// 스택 펼침 상태에서 카메라가 해당 글의 펼침 마커를 따라가는 데 쓴다.
  final void Function(int groupIndex, int postIndex)? onPostChanged;

  /// 카드 확장/축소 상태 변경 시 parent에 알림.
  final ValueChanged<bool>? onExpandedChanged;

  /// 내 글 수정/삭제(공유 시트)가 성공해 변경이 생겼을 때 parent에 알림.
  /// parent는 카드를 닫고 지도 마커를 새로고침한다.
  final VoidCallback? onPostEdited;

  /// **피드 카드 탭 진입 모드.** true 면 이 카드는 확장 상태로만 존재한다.
  ///
  /// 세 가지가 한꺼번에 달라진다. 셋을 별도 플래그로 쪼개지 않은 건, 셋 다
  /// "출발점이 어디였나"라는 **하나의 사실**에서 따라 나오기 때문이다.
  ///
  /// 1. 확장 상태로 바로 열린다.
  /// 2. 헤더에 뒤로가기 버튼이 붙는다 → 탭하면 [onClose] (= 피드로 복귀).
  /// 3. **아래로 드래그해도 기본 카드로 축소되지 않고 곧장 닫힌다.**
  ///
  /// 3번이 핵심이다. 마커 탭 경로는 기본 카드에서 **출발해** 확장으로 올라온
  /// 것이라 내리면 왔던 자리(기본 카드)로 돌아가는 게 맞다. 피드 경로는
  /// 출발점이 **피드 시트**다. 여기서 내렸을 때 한 번도 본 적 없는 기본 카드가
  /// 튀어나오면 "뒤로 간 게 아니라 다른 데로 갔다"고 읽힌다.
  ///
  /// 게다가 이 경로의 [groups] 는 항상 글 1개짜리라 기본 카드로 축소해도
  /// 좌우로 넘길 것이 없다. 축소 상태 자체가 무의미하다.
  ///
  /// 기존 마커 탭 경로는 기본값 false 로 동작이 바뀌지 않는다.
  final bool expandedOnly;

  /// 미리 받아둔 상세. 주면 [expandedOnly] 진입 시 `getBoardDetail` 을
  /// 다시 호출하지 않는다 (피드 카드 탭은 이미 상세를 받아 MapPost 를 만든다).
  final BoardPost? initialDetail;

  /// 주소 탭 핸들러. null 이면 주소는 탭할 수 없다(기존 마커 탭 경로).
  final VoidCallback? onLocationTap;

  /// **아래로 드래그해서 닫을 때만** 불린다. null 이면 [onClose] 로 폴백.
  /// [expandedOnly] 카드에서만 의미가 있다.
  ///
  /// 뒤로가기 버튼과 드래그를 갈라놓은 이유 — **제스처 방향이 곧 의도다.**
  ///
  /// - 뒤로가기 = "돌아간다". 보던 피드 시트가 그 높이 그대로 다시 있어야 한다.
  /// - 아래로 드래그 = "치운다". 손가락이 아래로 갔는데 피드가 올라온 채로
  ///   기다리고 있으면 내린 만큼 다시 올라온 꼴이라 이질감이 생긴다.
  ///
  /// 그래서 부모는 이 콜백에서 시트를 peek 까지 접는다.
  final VoidCallback? onDragDismiss;

  const MapBottomCard({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    this.initialPostIndex,
    required this.onClose,
    required this.minTopMargin,
    this.onGroupChanged,
    this.onPostChanged,
    this.onExpandedChanged,
    this.onPostEdited,
    this.expandedOnly = false,
    this.initialDetail,
    this.onLocationTap,
    this.onDragDismiss,
  });

  @override
  State<MapBottomCard> createState() => _MapBottomCardState();
}

class _MapBottomCardState extends State<MapBottomCard> {
  static const _defaultImageRatio = 0.50;
  static const _defaultTextRatio = 0.30;
  static const _defaultLongTextRatio = 0.40;
  static const _handleDragThreshold = 60.0;
  static const _handleVelocityThreshold = 300.0;
  // PageView viewportFraction — 가운데 카드 + 양옆 ~17px peek.
  static const _pageViewportFraction = 0.88;
  // 페이지 아이템 내부 좌우 패딩 — 카드 사이 시각적 간격.
  static const _pageItemHPadding = 4.0;
  // 핸들 영역 높이(기존 padding 10 + 바 4 + padding 22 = 36 과 동일).
  static const _handleAreaHeight = 36.0;
  // 뒤로가기 버튼이 붙을 때. 48 은 버튼 탭 타겟(48x48)을 담기 위한 최소값이다 —
  // 36 에 그냥 얹으면 Container 가 clipBehavior: antiAlias 라 잘려 나간다.
  static const _handleAreaHeightWithBack = 48.0;

  late PostGroupNavigator _nav;
  late PageController _pageController;
  // PageView 페이지 = (그룹, 그룹 내 글) 평탄화 목록.
  // 같은 자리 스택(A안): 스택 그룹의 글들이 연속 페이지로 이어져
  // 좌우 스와이프만으로 그룹 내 글 → 다음 마커로 자연스럽게 넘어간다.
  late List<({int g, int p})> _pages;
  int _currentPageIndex = 0;
  _CardState _cardState = _CardState.default_;
  double _handleDragAccum = 0;
  bool _isHandleDragging = false;

  BoardPost? _loadedDetail;
  bool _isLoadingDetail = false;

  // 좋아요 상태 override (post.id → LikeInfo). 사용자가 토글한 결과 보관.
  final Map<String, LikeInfo> _likeOverrides = {};
  bool _isLiking = false;

  void _rebuildPages() {
    _pages = [
      for (int g = 0; g < widget.groups.length; g++)
        for (int p = 0; p < widget.groups[g].length; p++) (g: g, p: p),
    ];
  }

  /// (그룹, 글) → 평탄화 페이지 인덱스. 못 찾으면 0 (방어).
  int _pageIndexOf(int g, [int p = 0]) {
    final idx = _pages.indexWhere((e) => e.g == g && e.p == p);
    return idx >= 0 ? idx : 0;
  }

  @override
  void initState() {
    super.initState();
    _rebuildPages();
    final initialPost = widget.initialPostIndex ?? 0;
    _nav = PostGroupNavigator(
      groups: widget.groups,
      initialGroupIndex: widget.initialGroupIndex,
      initialPostIndex: _safePostIndex(widget.initialGroupIndex, initialPost),
    );
    _currentPageIndex =
        _pageIndexOf(widget.initialGroupIndex, _nav.postIndex);
    _pageController = PageController(
      initialPage: _currentPageIndex,
      viewportFraction: _pageViewportFraction,
    );
    if (widget.expandedOnly) {
      _cardState = _CardState.expanded;
      _loadedDetail = widget.initialDetail;
      // setState 를 initState 에서 부를 수 없으므로 다음 프레임에 처리한다.
      // initialDetail 이 있으면 _loadDetail 은 가드로 즉시 리턴한다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onExpandedChanged?.call(true);
        unawaited(_loadDetail());
      });
    }
  }

  /// 그룹 범위를 벗어나는 postIndex 방어 (그룹 구성이 바뀐 직후 등).
  int _safePostIndex(int g, int p) {
    if (g < 0 || g >= widget.groups.length) return 0;
    return p.clamp(0, widget.groups[g].length - 1);
  }

  @override
  void didUpdateWidget(covariant MapBottomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final groupsChanged = oldWidget.groups != widget.groups;
    if (groupsChanged) {
      // 지도 재조회로 groups 가 통째로 바뀌는 경우 — 보던 글이 새 목록에도
      // 있으면 그 위치를 유지한다. 인덱스 기준으로만 리셋하면 목록이
      // 축소·재정렬됐을 때 옆의 다른 글로 튄다 (2026-07-13 카드-마커 불일치).
      final String? keepPostId =
          _nav.groupIndex < oldWidget.groups.length ? _nav.currentPost.id : null;
      _rebuildPages();
      int targetG = -1;
      int targetP = 0;
      if (keepPostId != null) {
        outer:
        for (int g = 0; g < widget.groups.length; g++) {
          for (int p = 0; p < widget.groups[g].length; p++) {
            if (widget.groups[g][p].id == keepPostId) {
              targetG = g;
              targetP = p;
              break outer;
            }
          }
        }
      }
      final bool samePostKept = targetG >= 0;
      if (!samePostKept) {
        targetG = widget.initialGroupIndex.clamp(0, widget.groups.length - 1);
        targetP = 0;
      }
      _nav = PostGroupNavigator(
        groups: widget.groups,
        initialGroupIndex: targetG,
        initialPostIndex: _safePostIndex(targetG, targetP),
      );
      // 같은 글을 계속 보는 중이면 확장 상태·로드된 상세도 유지 —
      // 백그라운드 새로고침이 읽던 화면을 접지 않게 한다.
      //
      // [expandedOnly] 카드는 여기서도 축소시키지 않는다. 이 경로의 groups 는
      // 매 빌드마다 새 리스트라 groupsChanged 가 항상 true 인데, 만에 하나
      // samePostKept 가 false 로 떨어지면 존재해선 안 될 기본 카드가 뜬다.
      if (!samePostKept && !widget.expandedOnly) {
        _cardState = _CardState.default_;
        _loadedDetail = null;
        _isLoadingDetail = false;
        widget.onExpandedChanged?.call(false);
      }
      _currentPageIndex = _pageIndexOf(targetG, _nav.postIndex);
      _pageController.dispose();
      _pageController = PageController(
        initialPage: _currentPageIndex,
        viewportFraction: _pageViewportFraction,
      );
      return;
    }

    // 외부 의도 감지: 그룹이 바뀌었거나(마커 탭), postIndex 강제가 새로 왔거나
    // (스택 펼침 마커 탭). 스와이프 에코(이미 그 그룹에 있고 post 강제 없음)는
    // 무시 — 뒤로 스와이프 시 스택 마지막 글에 머무는 게 자연스럽다.
    final bool groupIntent =
        oldWidget.initialGroupIndex != widget.initialGroupIndex;
    final bool postIntent = widget.initialPostIndex != null &&
        widget.initialPostIndex != oldWidget.initialPostIndex;
    if (!groupIntent && !postIntent) return;

    final current =
        _pageController.hasClients ? _pageController.page?.round() : null;
    final currentG = (current != null && current < _pages.length)
        ? _pages[current].g
        : null;
    // 그룹 에코 (post 강제 없음) → 무시
    if (widget.initialPostIndex == null &&
        currentG == widget.initialGroupIndex) {
      return;
    }

    final targetPost = _safePostIndex(
        widget.initialGroupIndex, widget.initialPostIndex ?? 0);
    final targetPage = _pageIndexOf(widget.initialGroupIndex, targetPost);
    if (current == targetPage) return; // 이미 그 페이지

    _nav.jumpTo(widget.initialGroupIndex, targetPost);
    _cardState = _CardState.default_;
    _loadedDetail = null;
    _isLoadingDetail = false;
    widget.onExpandedChanged?.call(false);
    _currentPageIndex = targetPage;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isImagePost => _nav.currentPost.fileInfoList.isNotEmpty;
  bool get _hasLongDefaultContent {
    final content = _nav.currentPost.content.trim();
    if (content.isEmpty) return false;
    final lineCount = '\n'.allMatches(content).length + 1;
    return lineCount >= 4 || content.length > 80;
  }

  // 특정 post 기준 좋아요 상태 (PageView에서 peek 카드도 자기 좋아요 상태 표시).
  bool _isLikedFor(MapPost post) =>
      _likeOverrides[post.id]?.isLike ?? post.isLike;
  int _likeCountFor(MapPost post) =>
      _likeOverrides[post.id]?.likeCount ?? post.likeCount;

  double _maxCardHeight(double screenHeight) =>
      screenHeight - widget.minTopMargin;

  double _baseCardHeight(double screenHeight) {
    final double ratio;
    if (_cardState == _CardState.default_) {
      if (_isImagePost) {
        ratio = _defaultImageRatio;
      } else {
        ratio = _hasLongDefaultContent ? _defaultLongTextRatio : _defaultTextRatio;
      }
    } else {
      ratio = 1.0;
    }
    return (screenHeight * ratio).clamp(0.0, _maxCardHeight(screenHeight));
  }

  double _cardHeight(double screenHeight) {
    final base = _baseCardHeight(screenHeight);
    if (!_isHandleDragging) return base;
    return (base - _handleDragAccum).clamp(0.0, _maxCardHeight(screenHeight));
  }

  // ── Handle drag (expand / collapse / close) ──────────────────────────

  void _onHandleDragStart(DragStartDetails d) {
    setState(() {
      _isHandleDragging = true;
      _handleDragAccum = 0;
    });
  }

  void _onHandleDragUpdate(DragUpdateDetails d) {
    setState(() => _handleDragAccum += d.delta.dy);
  }

  void _onHandleDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final drag = _handleDragAccum;
    _handleDragAccum = 0;

    if (_cardState == _CardState.default_) {
      if (drag < -_handleDragThreshold || v < -_handleVelocityThreshold) {
        _loadDetail();
        setState(() {
          _cardState = _CardState.expanded;
          _isHandleDragging = false;
        });
        widget.onExpandedChanged?.call(true);
      } else if (drag > _handleDragThreshold || v > _handleVelocityThreshold) {
        setState(() => _isHandleDragging = false);
        widget.onClose();
      } else {
        setState(() => _isHandleDragging = false);
      }
    } else {
      // expanded → (기본 카드로 축소) 또는 (피드 진입이면 곧장 닫기)
      if (drag > _handleDragThreshold || v > _handleVelocityThreshold) {
        if (widget.expandedOnly) {
          // 축소할 기본 카드가 없다 — 곧장 닫는다.
          // [onDragDismiss] 가 있으면 그쪽으로 간다. 부모가 피드 시트까지
          // 함께 접어서 "내린 만큼 내려가는" 그림을 만든다.
          setState(() => _isHandleDragging = false);
          (widget.onDragDismiss ?? widget.onClose)();
          return;
        }
        setState(() {
          _cardState = _CardState.default_;
          _loadedDetail = null;
          _isHandleDragging = false;
        });
        widget.onExpandedChanged?.call(false);
      } else {
        setState(() => _isHandleDragging = false);
      }
    }
  }

  void _onHandleDragCancel() {
    setState(() {
      _handleDragAccum = 0;
      _isHandleDragging = false;
    });
  }

  /// 카드 확장 (탭/제스처 공용 진입점).
  void _expandCard() {
    if (_cardState == _CardState.expanded) return;
    _loadDetail();
    setState(() => _cardState = _CardState.expanded);
    widget.onExpandedChanged?.call(true);
  }

  // ── 좋아요 ────────────────────────────────────────────────────────────

  bool get _isCurrentLiked =>
      _likeOverrides[_nav.currentPost.id]?.isLike ?? _nav.currentPost.isLike;

  int get _currentLikeCount =>
      _likeOverrides[_nav.currentPost.id]?.likeCount ??
      _nav.currentPost.likeCount;

  Future<void> _toggleLikeFor(MapPost post) async {
    if (_isLiking) return;
    _isLiking = true;
    try {
      final result = await BoardApiService().requestLike(post.id);
      if (result != null && mounted) {
        setState(() => _likeOverrides[post.id] = result);
      }
    } finally {
      _isLiking = false;
    }
  }

  Future<void> _toggleLike() => _toggleLikeFor(_nav.currentPost);

  // ── 수정 화면 이동 ──────────────────────────────────────────────────────

  Future<void> _navigateToEdit() async {
    // 상세가 아직 없으면 먼저 로드(공유 시트가 제목/내용/이미지를 채우는 데 필요).
    if (_loadedDetail == null) {
      await _loadDetail();
    }
    if (!mounted || _loadedDetail == null) return;
    // 별도 화면 이동 대신, 올라오는 공유 시트를 "수정 모드"로 띄운다.
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareCardSheet(editPost: _loadedDetail),
    );
    // 수정/삭제 성공 → 카드 닫고 지도 새로고침은 parent가 처리.
    if (changed == true) {
      widget.onPostEdited?.call();
    }
  }

  // ── PageView (글/그룹 좌우 스와이프) ──────────────────────────────────

  void _onPageChanged(int idx) {
    if (idx == _currentPageIndex) return;
    final entry = _pages[idx];
    final crossedGroup = entry.g != _nav.groupIndex;
    setState(() {
      _currentPageIndex = idx;
      _nav.jumpTo(entry.g, entry.p);
      _loadedDetail = null;
    });
    // 그룹(마커) 경계를 넘었을 때 parent에 알림 — 카메라 이동 + 하이라이트.
    if (crossedGroup) {
      widget.onGroupChanged?.call(entry.g);
    }
    // 글 단위 이동은 항상 알림 — 스택 펼침 상태에서 같은 그룹 안을 넘길 때
    // 카메라가 해당 펼침 마커를 따라가야 한다 (parent가 상황 판단).
    widget.onPostChanged?.call(entry.g, entry.p);
    // 경계는 PageView 자체가 막아주므로 별도 햅틱 없음.
    HapticFeedback.selectionClick();
  }

  // ── Detail lazy loading ───────────────────────────────────────────────

  Future<void> _loadDetail({bool force = false}) async {
    if (!force && _loadedDetail != null) return;
    setState(() => _isLoadingDetail = true);
    try {
      final detail = await BoardApiService().getBoardDetail(_nav.currentPost.id);
      if (mounted) {
        setState(() {
          _loadedDetail = detail;
          _isLoadingDetail = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final cardH = _cardHeight(screenH);
    final base = _baseCardHeight(screenH);
    final renderH = cardH > base ? cardH : base;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: _isHandleDragging
              ? Duration.zero
              : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          height: cardH,
          // 데코는 카드 자체(각 page item / expanded)로 이동 — peek 카드들이 시각적으로 분리되도록.
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: renderH,
            child: SizedBox(
              height: renderH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // PageView를 항상 트리에 유지 — 확장 상태에서도 PageController
                  // 위치가 보존되어, 스와이프 후 확장→축소 시 페이지가 어긋나지 않음.
                  Offstage(
                    offstage: _cardState == _CardState.expanded,
                    child: _buildSwipeablePages(context),
                  ),
                  if (_cardState == _CardState.expanded)
                    _buildExpandedCardShell(context),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── PageView (기본 상태) ──────────────────────────────────────────────

  Widget _buildSwipeablePages(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: _onPageChanged,
      // 가로 스크롤만 — 수직 드래그는 자식 GestureDetector(handle)로 전달.
      itemBuilder: (context, idx) {
        final entry = _pages[idx];
        final group = widget.groups[entry.g];
        final post = group[entry.p];
        final isCenter = idx == _currentPageIndex;
        return Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: _pageItemHPadding),
          child: Stack(
            children: [
              _buildCardShell(
                context: context,
                child: _buildDefaultContentFor(post, isCenter: isCenter),
                isHandleInteractive: isCenter,
              ),
              // 같은 자리 스택(2+ 글) — "n/N" 위치 표시 (마커 +N 뱃지와 호응)
              if (group.length > 1)
                Positioned(
                  top: 8,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.of(context).surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${entry.p + 1}/${group.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        color: AppColors.of(context).textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // 카드 외형(데코 + 핸들)을 그리는 공용 셸.
  Widget _buildCardShell({
    required BuildContext context,
    required Widget child,
    required bool isHandleInteractive,
  }) {
    // 기본(default) 중앙 카드일 때는 콘텐츠 영역도 수직 드래그로 확장/닫기 가능.
    // expanded 상태에선 내부 SingleChildScrollView가 스크롤을 가져가야 하므로 비활성.
    final enableContentDrag =
        isHandleInteractive && _cardState == _CardState.default_;
    final isExpanded = _cardState == _CardState.expanded;
    // 뒤로가기는 "돌아갈 곳이 있을 때"만 그린다. 마커 탭 경로는 확장을 내리면
    // 기본 카드로 돌아가므로 헤더 버튼이 하는 일을 핸들 드래그가 이미 한다.
    final showBack = isExpanded && widget.expandedOnly;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: isExpanded
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(24),
        // 카드 그림자 제거 — peek 영역에서 그림자가 지도 위로 번져 보이는 것 방지(요청).
        boxShadow: const [],
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart:
                isHandleInteractive ? _onHandleDragStart : null,
            onVerticalDragUpdate:
                isHandleInteractive ? _onHandleDragUpdate : null,
            onVerticalDragEnd:
                isHandleInteractive ? _onHandleDragEnd : null,
            onVerticalDragCancel:
                isHandleInteractive ? _onHandleDragCancel : null,
            child: SizedBox(
              height:
                  showBack ? _handleAreaHeightWithBack : _handleAreaHeight,
              child: Stack(
                children: [
                  // 핸들바 위치는 기존과 픽셀 단위로 같게 둔다(top 10).
                  // 기본 카드는 사용자가 가장 많이 보는 면이라 여기서 6px 이
                  // 밀리면 "왜 달라졌지" 싶어진다. 뒤로가기가 붙어 영역이 48 로
                  // 커질 때만 그 안에서 가운데((48-4)/2 = 22)로 온다.
                  Positioned(
                    top: showBack ? 22 : 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.of(context).divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  // 핸들바와 같은 줄에 놓지만 제스처는 충돌하지 않는다 —
                  // 부모는 onVerticalDrag, 이쪽은 onTap 이라 제스처 아레나가
                  // 포인터 이동량으로 갈라준다(움직이면 드래그, 안 움직이면 탭).
                  if (showBack)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onClose,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                // 다른 화면 헤더(상세글·설정)는 20 인데 여기만
                                // 16 이다. 저긴 AppBar 의 주인공이지만 여기선
                                // 옆에 놓인 핸들바가 이미 "내릴 수 있다"를
                                // 말하고 있어서, 같은 크기면 헤더가 시끄러워진다.
                                size: 16,
                                // 핸들바와 같은 divider 색. 둘은 같은 줄에서
                                // 같은 일(닫기)을 하므로 위계가 같아야 한다.
                                // 색을 명시하지 않으면 ThemeData 를 안 깐 탓에
                                // Material 기본색이 잡혀 다크모드에서 어긋난다.
                                color: AppColors.of(context).divider,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart:
                  enableContentDrag ? _onHandleDragStart : null,
              onVerticalDragUpdate:
                  enableContentDrag ? _onHandleDragUpdate : null,
              onVerticalDragEnd:
                  enableContentDrag ? _onHandleDragEnd : null,
              onVerticalDragCancel:
                  enableContentDrag ? _onHandleDragCancel : null,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedCardShell(BuildContext context) {
    return _buildCardShell(
      context: context,
      child: _buildExpandedContent(),
      isHandleInteractive: true,
    );
  }

  // ── 기본 상태 내용 ─────────────────────────────────────────────────────

  Widget _buildDefaultContentFor(MapPost post, {required bool isCenter}) {
    if (post.fileInfoList.isNotEmpty) {
      return _buildImagePostDefault(post, isCenter: isCenter);
    }
    return _buildTextPostDefault(post, isCenter: isCenter);
  }

  // PostInfoSection에 이상적으로 확보할 높이(본문 2줄까지 여유).
  static const _infoSectionReserved = 185.0;
  // 정보 영역이 반드시 확보해야 하는 최소 높이(줄일 수 없는 요소 합).
  // 패딩 27 + 헤더 47(내 글=수정버튼 포함) + 제목 24 + 간격 20 + 좋아요행 19 ≈ 137 → 여유 포함 150.
  // 카드가 짧으면 이미지를 이 값 확보를 위해 _imageHeightMin(120) 밑으로도 줄인다.
  static const _infoSectionMin = 150.0;
  static const _imageHeightMin = 120.0;
  static const _imageHeightMax = 250.0;

  Widget _buildImagePostDefault(MapPost post, {required bool isCenter}) {
    return LayoutBuilder(builder: (context, constraints) {
      // 이미지 하단 패딩(4px)을 제외한 사용 가능 높이.
      final double available = constraints.maxHeight - 4;
      // 카드가 짧을 때 정보 최소 높이를 우선 확보 → 이미지가 가질 수 있는 상한.
      final double maxImageForInfo =
          (available - _infoSectionMin).clamp(0.0, _imageHeightMax).toDouble();
      // 이상적으로는 reserved(185)를 정보에 양보하지만, 정보 최소 확보가 우선.
      final double imageH = (available - _infoSectionReserved)
          .clamp(_imageHeightMin, _imageHeightMax)
          .clamp(0.0, maxImageForInfo)
          .toDouble();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PostImageCarousel(
                images: post.fileInfoList,
                height: imageH,
                initialIndex: isCenter ? _nav.currentImageIndex : 0,
                onIndexChanged: (i) {
                  if (isCenter) _nav.updateImageIndex(i);
                },
              ),
            ),
          ),
          Expanded(
            child: PostInfoSection(
              post: post,
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 15),
              showDetailButton: false,
              isLiked: _isLikedFor(post),
              likeCountOverride: _likeCountFor(post),
              onLikeTap: () => _toggleLikeFor(post),
              onReplyTap: isCenter ? _expandCard : null,
              onShowMore: isCenter ? _expandCard : null,
              onEditTap: (post.isOwner && isCenter) ? _navigateToEdit : null,
              // 상세 화면이 없는 흐름이라 여기가 공유의 주 진입점이다.
              showShare: isCenter,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildTextPostDefault(MapPost post, {required bool isCenter}) {
    final colors = AppColors.of(context);
    // 노출 제한(48시간)까지 남은 시간. 만료/계산불가면 빈 문자열 → 뱃지 숨김.
    final remaining = remainingTimeFromString(post.createdAt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 프로필 + 이름 + 시간 + 24h 뱃지
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: colors.surfaceVariant),
                clipBehavior: Clip.antiAlias,
                child: post.profileImage != null && post.profileImage!.isNotEmpty
                    ? CachedNetworkImage(imageUrl: post.profileImage!, fit: BoxFit.cover)
                    : Icon(Icons.person_outline,
                        size: 18, color: colors.textMuted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.nickname,
                        style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary)),
                    Text(relativeTimeFromString(post.createdAt),
                        style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Pretendard',
                            color: colors.textTertiary)),
                  ],
                ),
              ),
              // 노출 만료까지 남은 시간 뱃지 (시계 아이콘 + "N시간/N일 남음")
              if (remaining.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.13),
                      border: Border.all(
                          color: colors.accent.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 11, color: colors.accent),
                      const SizedBox(width: 3),
                      Text(remaining,
                          style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                              color: colors.accent)),
                    ],
                  ),
                ),
              if (post.isOwner && isCenter) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _navigateToEdit,
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
          const SizedBox(height: 10),
          // 텍스트 내용 — 카드 영역을 넘으면 ellipsis + "더보기"로 확장 유도.
          Expanded(
            child: _OverflowingTextWithMore(
              text: post.content,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Pretendard',
                color: colors.textPrimary,
                height: 1.5,
              ),
              moreColor: colors.primaryStrong,
              surfaceColor: colors.surface,
              onExpand: isCenter ? _expandCard : null,
            ),
          ),
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final liked = _isLikedFor(post);
            // 지표는 왼쪽, 행동(공유)은 오른쪽. 사진 글(PostInfoSection)과 동일한 배치.
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggleLikeFor(post),
                      child: Row(
                        children: [
                          Icon(
                            liked ? Icons.favorite : Icons.favorite_outline,
                            size: 15,
                            color: liked ? colors.danger : colors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text('${_likeCountFor(post)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Pretendard',
                                  color: colors.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isCenter ? _expandCard : null,
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 14, color: colors.primaryStrong),
                          const SizedBox(width: 4),
                          Text('${post.replyCount}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Pretendard',
                                  color: colors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                // 사진 글과 같은 자리에 같은 아이콘을 둔다.
                // 글 종류에 따라 공유 버튼이 있다 없다 하면 사용자가 못 찾는다.
                if (isCenter && post.shareUrl != null)
                  Builder(
                    builder: (buttonContext) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => PostShare.share(
                        context: buttonContext,
                        shareUrl: post.shareUrl!,
                        title: post.title,
                      ),
                      // 회색 — 본문 우하단 "더보기"와 파랑이 겹치지 않게.
                      // 근거는 PostInfoSection 의 같은 아이콘 주석 참고.
                      child: Icon(Icons.ios_share_rounded,
                          size: 15, color: colors.textMuted),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── 확장 상태 내용 ─────────────────────────────────────────────────────

  Widget _buildExpandedContent() {
    final post = _nav.currentPost;
    return Column(
      children: [
        if (_isImagePost)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PostImageCarousel(
                images: post.fileInfoList,
                initialIndex: _nav.currentImageIndex,
                onIndexChanged: (i) => _nav.updateImageIndex(i),
              ),
            ),
          ),
        Expanded(
          child: MapCardExpandedContent(
            post: post,
            detail: _loadedDetail,
            isLoading: _isLoadingDetail,
            isLiked: _isCurrentLiked,
            likeCountOverride: _currentLikeCount,
            onLikeTap: _toggleLike,
            onRefreshDetail: () => _loadDetail(force: true),
            onEditTap: post.isOwner ? _navigateToEdit : null,
            onLocationTap: widget.onLocationTap,
          ),
        ),
      ],
    );
  }
}

/// 텍스트가 주어진 영역(높이)을 넘으면 마지막 줄 우측에 "더보기" 오버레이 표시.
/// 들어맞으면 전체 텍스트 그대로 렌더, "더보기" 숨김.
///
/// [onExpand]가 null이면(=peek 카드) "더보기"가 보여도 탭 비활성.
class _OverflowingTextWithMore extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color moreColor;
  final Color surfaceColor;
  final VoidCallback? onExpand;

  const _OverflowingTextWithMore({
    required this.text,
    required this.style,
    required this.moreColor,
    required this.surfaceColor,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: constraints.maxWidth);
      final fits = tp.height <= constraints.maxHeight;
      tp.dispose();

      if (fits) {
        return Text(text, style: style);
      }

      return SizedBox(
        width: double.infinity,
        child: Stack(
        children: [
          Text(
            text,
            style: style,
            overflow: TextOverflow.ellipsis,
            maxLines: 999,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onExpand,
              child: Container(
                padding: const EdgeInsets.only(left: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      surfaceColor.withValues(alpha: 0),
                      surfaceColor,
                    ],
                    stops: const [0, 0.3],
                  ),
                ),
                child: Text(
                  '더보기',
                  style: style.copyWith(
                    fontWeight: FontWeight.w600,
                    color: moreColor,
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      );
    });
  }
}
