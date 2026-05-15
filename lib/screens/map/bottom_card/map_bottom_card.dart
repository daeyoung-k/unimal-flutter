// lib/screens/map/bottom_card/map_bottom_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:unimal/screens/map/bottom_card/map_card_expanded_content.dart';
import 'package:unimal/screens/map/bottom_card/map_thumbnail_strip.dart';
import 'package:unimal/screens/map/bottom_card/post_group_navigator.dart';
import 'package:unimal/screens/map/bottom_card/post_image_carousel.dart';
import 'package:unimal/screens/map/bottom_card/post_info_section.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';
import 'package:unimal/theme/app_colors.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/board/model/like_info.dart';
import 'package:unimal/service/map/models/map_post.dart';

/// 카드 상태: 기본(default_) 또는 확장(expanded).
/// 닫힘은 onClose 콜백으로 부모에서 처리.
enum _CardState { default_, expanded }

/// 지도 마커 탭 시 표시되는 카드 + 썸네일 스트립.
///
/// 레이아웃 (아래에서 위):
///   [카드 본문] ← AnimatedContainer, 높이 변동
///   [썸네일 스트립] ← 카드 바로 위 부유, 확장 시 minTopMargin에 고정
///
/// 제스처:
///   - 핸들 위 드래그(≥60px / 300px/s) → 확장
///   - 핸들 아래 드래그(≥60px / 300px/s) → 기본→닫힘, 확장→기본
///   - 카드 좌우 스와이프(기본 상태만, ≥60px / 300px/s) → 이전/다음 마커
///   - 스트립 썸네일 탭 → 해당 마커로 점프
///   - 이미지 ‹ › 탭 → 같은 게시글 사진 전환 (PostImageCarousel이 처리)
class MapBottomCard extends StatefulWidget {
  final List<List<MapPost>> groups;
  final int initialGroupIndex;
  final ValueChanged<NLatLng> onCameraMove;
  final VoidCallback onClose;

  /// 스트립이 올라갈 수 있는 화면 상단 한계 (검색바+필터 하단).
  /// map_naver.dart에서 safeAreaTop + 약 100px로 전달.
  final double minTopMargin;

  /// 사용자가 다른 그룹으로 이동했을 때 parent에 알림.
  /// (스트립 탭, 좌우 마커 스와이프)
  final ValueChanged<int>? onGroupChanged;

  const MapBottomCard({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    required this.onCameraMove,
    required this.onClose,
    required this.minTopMargin,
    this.onGroupChanged,
  });

  @override
  State<MapBottomCard> createState() => _MapBottomCardState();
}

class _MapBottomCardState extends State<MapBottomCard> {
  static const _defaultTextRatio = 0.30;
  static const _defaultLongTextRatio = 0.40;
  static const _hSwipeMinDistance = 60.0;
  static const _hSwipeMinVelocity = 300.0;
  static const _handleDragThreshold = 60.0;
  static const _handleVelocityThreshold = 300.0;
  // 실측: 썸네일 활성 70 + 상하 패딩 6×2 = 82
  static const _stripHeight = 82.0;
  static const _stripCardGap = 8.0;

  late PostGroupNavigator _nav;
  _CardState _cardState = _CardState.default_;
  double _hDragAccum = 0;
  double _handleDragAccum = 0;
  bool _isHandleDragging = false;

  BoardPost? _loadedDetail;
  bool _isLoadingDetail = false;

  // 좋아요 상태 override (post.id → LikeInfo). 사용자가 토글한 결과 보관.
  final Map<String, LikeInfo> _likeOverrides = {};
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _nav = PostGroupNavigator(
      groups: widget.groups,
      initialGroupIndex: widget.initialGroupIndex,
    );
  }

  @override
  void didUpdateWidget(covariant MapBottomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialGroupIndex != widget.initialGroupIndex ||
        oldWidget.groups != widget.groups) {
      _nav = PostGroupNavigator(
        groups: widget.groups,
        initialGroupIndex: widget.initialGroupIndex,
      );
      _cardState = _CardState.default_;
      _loadedDetail = null;
      _isLoadingDetail = false;
    }
  }

  bool get _isImagePost => _nav.currentPost.fileInfoList.isNotEmpty;
  bool get _hasLongDefaultContent {
    final content = _nav.currentPost.content.trim();
    if (content.isEmpty) return false;
    final lineCount = '\n'.allMatches(content).length + 1;
    return lineCount >= 4 || content.length > 80;
  }

  int get _defaultContentMaxLines => _hasLongDefaultContent ? 4 : 2;

  double _maxCardHeight(double screenHeight) =>
      screenHeight - widget.minTopMargin - _stripHeight - _stripCardGap;

  double _baseCardHeight(double screenHeight) {
    final ratio = _cardState == _CardState.default_
        ? (_hasLongDefaultContent ? _defaultLongTextRatio : _defaultTextRatio)
        : 1.0;
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
      } else if (drag > _handleDragThreshold || v > _handleVelocityThreshold) {
        setState(() => _isHandleDragging = false);
        widget.onClose();
      } else {
        setState(() => _isHandleDragging = false);
      }
    } else {
      // expanded → shrink to default
      if (drag > _handleDragThreshold || v > _handleVelocityThreshold) {
        setState(() {
          _cardState = _CardState.default_;
          _loadedDetail = null;
          _isHandleDragging = false;
        });
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
  }

  // ── 좋아요 ────────────────────────────────────────────────────────────

  bool get _isCurrentLiked =>
      _likeOverrides[_nav.currentPost.id]?.isLike ?? _nav.currentPost.isLike;

  int get _currentLikeCount =>
      _likeOverrides[_nav.currentPost.id]?.likeCount ??
      _nav.currentPost.likeCount;

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    _isLiking = true;
    final postId = _nav.currentPost.id;
    try {
      final result = await BoardApiService().requestLike(postId);
      if (result != null && mounted) {
        setState(() => _likeOverrides[postId] = result);
      }
    } finally {
      _isLiking = false;
    }
  }

  // ── Horizontal swipe (marker navigation, default state only) ─────────

  void _onHorizDragUpdate(DragUpdateDetails d) {
    _hDragAccum += d.delta.dx;
  }

  void _onHorizDragEnd(DragEndDetails d) {
    if (_cardState == _CardState.expanded) {
      _hDragAccum = 0;
      return;
    }
    final v = d.primaryVelocity ?? 0;
    final drag = _hDragAccum;
    _hDragAccum = 0;

    if (drag > _hSwipeMinDistance || v > _hSwipeMinVelocity) {
      _navigateGroup(-1); // swipe right → prev
    } else if (drag < -_hSwipeMinDistance || v < -_hSwipeMinVelocity) {
      _navigateGroup(1); // swipe left → next
    }
  }

  void _navigateGroup(int direction) {
    final result = direction > 0 ? _nav.nextGroup() : _nav.prevGroup();
    if (result == true) {
      widget.onCameraMove(
        NLatLng(_nav.currentPost.latitude, _nav.currentPost.longitude),
      );
      widget.onGroupChanged?.call(_nav.groupIndex);
      setState(() => _loadedDetail = null);
    } else if (result == null) {
      HapticFeedback.lightImpact();
    }
  }

  /// 드래그 중 strip이 시각적 활성 인덱스를 알릴 때 호출.
  /// 카드 본문(이미지/텍스트/좋아요)을 즉시 동기화. 카메라 이동/parent 통지는 생략.
  void _previewGroup(int groupIndex) {
    if (groupIndex == _nav.groupIndex) return;
    _nav.jumpToGroup(groupIndex);
    setState(() {
      _cardState = _CardState.default_;
      _loadedDetail = null;
    });
  }

  void _jumpToGroup(int groupIndex) {
    // drag end 또는 탭 commit. drag 중 _previewGroup으로 _nav가 이미 변경됐을 수 있음.
    if (groupIndex != _nav.groupIndex) {
      _nav.jumpToGroup(groupIndex);
    }
    widget.onCameraMove(
      NLatLng(_nav.currentPost.latitude, _nav.currentPost.longitude),
    );
    widget.onGroupChanged?.call(_nav.groupIndex);
    setState(() {
      _cardState = _CardState.default_;
      _loadedDetail = null;
    });
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
        // 썸네일 스트립
        MapThumbnailStrip(
          groups: widget.groups,
          currentGroupIndex: _nav.groupIndex,
          onTap: _jumpToGroup,
          onVisualIndexChange: _previewGroup,
        ),
        const SizedBox(height: _stripCardGap),
        // 카드 본문
        AnimatedContainer(
          duration: _isHandleDragging
              ? Duration.zero
              : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          height: cardH,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.of(context).shadow,
                  blurRadius: 20,
                  offset: const Offset(0, -4)),
            ],
          ),
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: renderH,
            child: SizedBox(
              height: renderH,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: _onHorizDragUpdate,
                onHorizontalDragEnd: _onHorizDragEnd,
                onHorizontalDragCancel: () => _hDragAccum = 0,
                // 기본 상태에서만 카드 전체로 수직 드래그 받음.
                // expanded 상태에선 null로 두어 내부 SingleChildScrollView가 스크롤을 가져감.
                onVerticalDragStart: _cardState == _CardState.default_
                    ? _onHandleDragStart
                    : null,
                onVerticalDragUpdate: _cardState == _CardState.default_
                    ? _onHandleDragUpdate
                    : null,
                onVerticalDragEnd: _cardState == _CardState.default_
                    ? _onHandleDragEnd
                    : null,
                onVerticalDragCancel: _cardState == _CardState.default_
                    ? _onHandleDragCancel
                    : null,
                child: Column(
                  children: [
                    // 핸들 (수직 드래그 전용)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: _onHandleDragStart,
                      onVerticalDragUpdate: _onHandleDragUpdate,
                      onVerticalDragEnd: _onHandleDragEnd,
                      onVerticalDragCancel: _onHandleDragCancel,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 22),
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
                    ),
                    // 카드 내용 — 그룹 변경 시 cross-fade
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        layoutBuilder: (currentChild, previousChildren) => Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        ),
                        child: KeyedSubtree(
                          // post id + 상태 조합 → 그룹/상태 변경 시 새 child로 fade
                          key: ValueKey(
                              '${_nav.currentPost.id}_${_cardState.name}'),
                          child: _cardState == _CardState.expanded
                              ? _buildExpandedContent()
                              : _buildDefaultContent(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 기본 상태 내용 ─────────────────────────────────────────────────────

  Widget _buildDefaultContent() {
    final post = _nav.currentPost;
    if (_isImagePost) return _buildImagePostDefault(post);
    return _buildTextPostDefault(post);
  }

  Widget _buildImagePostDefault(MapPost post) {
    return PostInfoSection(
      post: post,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      showDetailButton: false,
      isLiked: _isCurrentLiked,
      likeCountOverride: _currentLikeCount,
      contentMaxLines: _defaultContentMaxLines,
      onLikeTap: _toggleLike,
      onReplyTap: _expandCard,
    );
  }

  Widget _buildTextPostDefault(MapPost post) {
    final colors = AppColors.of(context);
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.13),
                    border: Border.all(
                        color: colors.accent.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('24h',
                    style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Pretendard',
                        color: colors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 텍스트 내용 — textPrimary 사용 (다크에서 흰색 가까이)
          Expanded(
            child: Text(
              post.content,
              style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Pretendard',
                  color: colors.textPrimary,
                  height: 1.5),
              overflow: TextOverflow.fade,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleLike,
                child: Row(
                  children: [
                    Icon(
                      _isCurrentLiked ? Icons.favorite : Icons.favorite_outline,
                      size: 15,
                      color:
                          _isCurrentLiked ? colors.danger : colors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text('$_currentLikeCount',
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
                onTap: _expandCard,
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
          PostImageCarousel(
            images: post.fileInfoList,
            initialIndex: _nav.currentImageIndex,
            onIndexChanged: (i) => _nav.updateImageIndex(i),
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
          ),
        ),
      ],
    );
  }
}
