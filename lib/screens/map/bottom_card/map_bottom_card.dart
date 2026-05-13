import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:unimal/screens/map/bottom_card/post_group_navigator.dart';
import 'package:unimal/screens/map/bottom_card/post_image_carousel.dart';
import 'package:unimal/screens/map/bottom_card/post_info_section.dart';
import 'package:unimal/service/map/models/map_post.dart';

/// 2-stage snap sheet: peek (~30%) and full (~55%).
///
/// Gestures:
/// - peek: 위 드래그(≥60px) → full, 아래 드래그(≥60px) → onClose, 탭 → full
/// - full: 위 스와이프(vel ≥ 300 px/s 또는 drag ≥ 80px) → next post,
///         아래 스와이프(동일 임계값) → prev post
/// - 핸들 탭 → onClose
///
/// 좌우 스와이프는 자식 [PostImageCarousel]이 흡수하여 시트로 전달되지 않음.
enum _SheetState { peek, full }

class MapBottomCard extends StatefulWidget {
  final List<List<MapPost>> groups;
  final int initialGroupIndex;
  final ValueChanged<NLatLng> onCameraMove;
  final VoidCallback onClose;

  const MapBottomCard({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    required this.onCameraMove,
    required this.onClose,
  });

  @override
  State<MapBottomCard> createState() => _MapBottomCardState();
}

class _MapBottomCardState extends State<MapBottomCard> {
  static const double _peekRatio = 0.30;
  static const double _fullRatio = 0.55;
  static const double _peekDragThreshold = 60;
  static const double _postSwipeMinVelocity = 300;
  static const double _postSwipeMinDistance = 80;

  late PostGroupNavigator _nav;
  _SheetState _state = _SheetState.peek;
  double _accumulatedDrag = 0;

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
    // 외부에서 다른 마커 탭으로 진입 시 그룹 인덱스 동기화
    if (oldWidget.initialGroupIndex != widget.initialGroupIndex ||
        oldWidget.groups != widget.groups) {
      _nav = PostGroupNavigator(
        groups: widget.groups,
        initialGroupIndex: widget.initialGroupIndex,
      );
      setState(() => _state = _SheetState.peek);
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _accumulatedDrag += details.delta.dy;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final drag = _accumulatedDrag;
    _accumulatedDrag = 0;

    if (_state == _SheetState.peek) {
      if (drag <= -_peekDragThreshold) {
        setState(() => _state = _SheetState.full);
      } else if (drag >= _peekDragThreshold) {
        widget.onClose();
      }
      return;
    }

    // full 상태: 위 스와이프 = 다음, 아래 스와이프 = 이전
    final isUpSwipe = drag <= -_postSwipeMinDistance || velocity <= -_postSwipeMinVelocity;
    final isDownSwipe = drag >= _postSwipeMinDistance || velocity >= _postSwipeMinVelocity;

    if (isUpSwipe) {
      final result = _nav.next();
      if (result == true) {
        widget.onCameraMove(NLatLng(_nav.currentPost.latitude, _nav.currentPost.longitude));
      } else if (result == null) {
        HapticFeedback.lightImpact(); // 끝 도달 — 약한 bounce 피드백
      }
      setState(() {}); // _nav mutated synchronously above; rebuild for new currentPost/currentImageIndex
    } else if (isDownSwipe) {
      final result = _nav.prev();
      if (result == true) {
        widget.onCameraMove(NLatLng(_nav.currentPost.latitude, _nav.currentPost.longitude));
      } else if (result == null) {
        HapticFeedback.lightImpact(); // 처음 도달 — 약한 bounce 피드백
      }
      setState(() {}); // _nav mutated synchronously above; rebuild for new currentPost/currentImageIndex
    }
  }

  void _handleHandleTap() => widget.onClose();

  void _handleCardTap() {
    if (_state == _SheetState.peek) {
      setState(() => _state = _SheetState.full);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final height = (_state == _SheetState.peek ? _peekRatio : _fullRatio) * size.height;
    final post = _nav.currentPost;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        onVerticalDragCancel: () => _accumulatedDrag = 0,
        onTap: _handleCardTap,
        child: Column(
          children: [
            // 핸들
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleHandleTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // 본문
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    PostImageCarousel(
                      images: post.fileInfoList,
                      initialIndex: _nav.currentImageIndex,
                      onIndexChanged: (i) => _nav.updateImageIndex(i),
                    ),
                    PostInfoSection(
                      post: post,
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + safeBottom),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
