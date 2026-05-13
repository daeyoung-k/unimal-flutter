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
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
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

  const MapBottomCard({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    required this.onCameraMove,
    required this.onClose,
    required this.minTopMargin,
  });

  @override
  State<MapBottomCard> createState() => _MapBottomCardState();
}

class _MapBottomCardState extends State<MapBottomCard> {
  static const _defaultImageRatio = 0.62;
  static const _defaultTextRatio = 0.38;
  static const _hSwipeMinDistance = 60.0;
  static const _hSwipeMinVelocity = 300.0;
  static const _handleDragThreshold = 60.0;
  static const _handleVelocityThreshold = 300.0;
  static const _stripHeight = 60.0;
  static const _stripCardGap = 8.0;

  late PostGroupNavigator _nav;
  _CardState _cardState = _CardState.default_;
  double _hDragAccum = 0;
  double _handleDragAccum = 0;

  BoardPost? _loadedDetail;
  bool _isLoadingDetail = false;

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

  double _cardHeight(double screenHeight) {
    final maxCardH = screenHeight - widget.minTopMargin - _stripHeight - _stripCardGap;
    final ratio = _cardState == _CardState.default_
        ? (_isImagePost ? _defaultImageRatio : _defaultTextRatio)
        : 1.0;
    return (screenHeight * ratio).clamp(0.0, maxCardH);
  }

  // ── Handle drag (expand / collapse / close) ──────────────────────────

  void _onHandleDragUpdate(DragUpdateDetails d) {
    _handleDragAccum += d.delta.dy;
  }

  void _onHandleDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final drag = _handleDragAccum;
    _handleDragAccum = 0;

    if (_cardState == _CardState.default_) {
      if (drag < -_handleDragThreshold || v < -_handleVelocityThreshold) {
        _loadDetail();
        setState(() => _cardState = _CardState.expanded);
      } else if (drag > _handleDragThreshold || v > _handleVelocityThreshold) {
        widget.onClose();
      }
    } else {
      // expanded → shrink to default
      if (drag > _handleDragThreshold || v > _handleVelocityThreshold) {
        setState(() {
          _cardState = _CardState.default_;
          _loadedDetail = null;
        });
      }
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
      setState(() => _loadedDetail = null);
    } else if (result == null) {
      HapticFeedback.lightImpact();
    }
  }

  void _jumpToGroup(int groupIndex) {
    if (groupIndex == _nav.groupIndex) return;
    _nav.jumpToGroup(groupIndex);
    widget.onCameraMove(
      NLatLng(_nav.currentPost.latitude, _nav.currentPost.longitude),
    );
    setState(() {
      _cardState = _CardState.default_;
      _loadedDetail = null;
    });
  }

  // ── Detail lazy loading ───────────────────────────────────────────────

  Future<void> _loadDetail() async {
    if (_loadedDetail != null) return;
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 썸네일 스트립
        MapThumbnailStrip(
          groups: widget.groups,
          currentGroupIndex: _nav.groupIndex,
          onTap: _jumpToGroup,
        ),
        const SizedBox(height: _stripCardGap),
        // 카드 본문
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          height: cardH,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _onHorizDragUpdate,
            onHorizontalDragEnd: _onHorizDragEnd,
            onHorizontalDragCancel: () => _hDragAccum = 0,
            child: Column(
              children: [
                // 핸들 (수직 드래그 전용)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _onHandleDragUpdate,
                  onVerticalDragEnd: _onHandleDragEnd,
                  onVerticalDragCancel: () => _handleDragAccum = 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDDDDD),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                // 카드 내용
                Expanded(
                  child: _cardState == _CardState.expanded
                      ? _buildExpandedContent()
                      : _buildDefaultContent(),
                ),
              ],
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
    return Column(
      children: [
        PostImageCarousel(
          images: post.fileInfoList,
          initialIndex: _nav.currentImageIndex,
          onIndexChanged: (i) => _nav.updateImageIndex(i),
        ),
        Expanded(
          child: PostInfoSection(
            post: post,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            showDetailButton: false,
          ),
        ),
      ],
    );
  }

  Widget _buildTextPostDefault(MapPost post) {
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
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF5F5F5)),
                clipBehavior: Clip.antiAlias,
                child: post.profileImage != null && post.profileImage!.isNotEmpty
                    ? CachedNetworkImage(imageUrl: post.profileImage!, fit: BoxFit.cover)
                    : const Icon(Icons.person_outline, size: 18, color: Color(0xFFBBBBBB)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.nickname,
                        style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151))),
                    Text(relativeTimeFromString(post.createdAt),
                        style: const TextStyle(fontSize: 11, fontFamily: 'Pretendard', color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0x22FF9F43),
                    border: Border.all(color: const Color(0x66FF9F43)),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('24h',
                    style: TextStyle(fontSize: 10, fontFamily: 'Pretendard', color: Color(0xFFFF9F43))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 텍스트 내용
          Expanded(
            child: Text(
              post.content,
              style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Pretendard',
                  color: Color(0xFF4B5563),
                  height: 1.5),
              overflow: TextOverflow.fade,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.favorite, size: 15, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 4),
              Text('${post.likeCount}',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Pretendard', color: Color(0xFF9E9E9E))),
              const SizedBox(width: 14),
              const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFF4D91FF)),
              const SizedBox(width: 4),
              Text('${post.replyCount}',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Pretendard', color: Color(0xFF9E9E9E))),
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
          ),
        ),
      ],
    );
  }
}
