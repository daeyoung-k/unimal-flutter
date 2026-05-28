// lib/screens/map/bottom_card/map_bottom_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
  final VoidCallback onClose;

  /// 카드가 올라갈 수 있는 화면 상단 한계 (검색바+필터 하단).
  /// map_naver.dart에서 safeAreaTop + 약 100px로 전달.
  final double minTopMargin;

  /// 사용자가 다른 그룹으로 이동했을 때 parent에 알림.
  /// (좌우 카드 스와이프) parent는 카메라 이동 + 마커 하이라이트 + 스트립 위치 갱신을 처리한다.
  final ValueChanged<int>? onGroupChanged;

  /// 카드 확장/축소 상태 변경 시 parent에 알림.
  final ValueChanged<bool>? onExpandedChanged;

  const MapBottomCard({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    required this.onClose,
    required this.minTopMargin,
    this.onGroupChanged,
    this.onExpandedChanged,
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

  late PostGroupNavigator _nav;
  late PageController _pageController;
  _CardState _cardState = _CardState.default_;
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
    _pageController = PageController(
      initialPage: widget.initialGroupIndex,
      viewportFraction: _pageViewportFraction,
    );
  }

  @override
  void didUpdateWidget(covariant MapBottomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final groupsChanged = oldWidget.groups != widget.groups;
    final indexChanged =
        oldWidget.initialGroupIndex != widget.initialGroupIndex;
    if (groupsChanged) {
      _nav = PostGroupNavigator(
        groups: widget.groups,
        initialGroupIndex: widget.initialGroupIndex,
      );
      _cardState = _CardState.default_;
      _loadedDetail = null;
      _isLoadingDetail = false;
      _pageController.dispose();
      _pageController = PageController(
        initialPage: widget.initialGroupIndex,
        viewportFraction: _pageViewportFraction,
      );
      widget.onExpandedChanged?.call(false);
    } else if (indexChanged) {
      // 외부 트리거(마커 탭 등) — PageView를 새 인덱스로 애니메이션.
      _nav.jumpToGroup(widget.initialGroupIndex);
      _cardState = _CardState.default_;
      _loadedDetail = null;
      _isLoadingDetail = false;
      widget.onExpandedChanged?.call(false);
      if (_pageController.hasClients) {
        final current = _pageController.page?.round();
        if (current != widget.initialGroupIndex) {
          _pageController.animateToPage(
            widget.initialGroupIndex,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        }
      }
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
      // expanded → shrink to default
      if (drag > _handleDragThreshold || v > _handleVelocityThreshold) {
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
    if (_loadedDetail != null) {
      Get.toNamed('/edit-board', arguments: _loadedDetail);
      return;
    }
    await _loadDetail();
    if (mounted && _loadedDetail != null) {
      Get.toNamed('/edit-board', arguments: _loadedDetail);
    }
  }

  // ── PageView (그룹 좌우 스와이프) ─────────────────────────────────────

  void _onPageChanged(int idx) {
    if (idx == _nav.groupIndex) return;
    setState(() {
      _nav.jumpToGroup(idx);
      _loadedDetail = null;
    });
    widget.onGroupChanged?.call(idx);
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
      itemCount: widget.groups.length,
      onPageChanged: _onPageChanged,
      // 가로 스크롤만 — 수직 드래그는 자식 GestureDetector(handle)로 전달.
      itemBuilder: (context, idx) {
        final post = widget.groups[idx].first;
        final isCenter = idx == _nav.groupIndex;
        return Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: _pageItemHPadding),
          child: _buildCardShell(
            context: context,
            child: _buildDefaultContentFor(post, isCenter: isCenter),
            isHandleInteractive: isCenter,
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: isExpanded
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(24),
        boxShadow: isExpanded
            ? []
            : [
                BoxShadow(
                  color: AppColors.of(context).shadow,
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
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

  // PostInfoSection에 항상 확보할 최소 높이.
  // (패딩 27 + 헤더~47(수정버튼 포함) + 타이틀~24 + SizedBox 20 + 내용 2줄~40 + 좋아요행~19 = ~177)
  // 여유분 포함해 185로 설정.
  static const _infoSectionReserved = 185.0;
  static const _imageHeightMin = 120.0;
  static const _imageHeightMax = 250.0;

  Widget _buildImagePostDefault(MapPost post, {required bool isCenter}) {
    return LayoutBuilder(builder: (context, constraints) {
      // 이미지 하단 패딩(4px)을 포함해 PostInfoSection이 _infoSectionReserved를 확보하도록 계산.
      final imageH = (constraints.maxHeight - _infoSectionReserved - 4)
          .clamp(_imageHeightMin, _imageHeightMax);
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
            ),
          ),
        ],
      );
    });
  }

  Widget _buildTextPostDefault(MapPost post, {required bool isCenter}) {
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
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
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
