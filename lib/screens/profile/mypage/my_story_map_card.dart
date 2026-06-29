import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:unimal/screens/profile/mypage/story_marker.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/theme/app_colors.dart';

/// 마이페이지 '내 스토리' 영역의 지도 미리보기 카드.
///
/// 내 글 위치를 라이브 네이버 미니맵(제스처 off · lite 모드)으로 보여주고,
/// 탭하면 [onTap]으로 내 스토리 전용 지도 화면 진입을 위임한다.
///
/// 비용 메모: Dynamic Map은 지도 뷰 1회 생성(onCreate)당 1건 과금되며
/// 대표 계정 월 600만 건까지 무료다. lite 모드 + 제스처 off로 렌더 부하를
/// 낮추고, 부모에서 글이 있을 때만 생성해 불필요한 뷰 생성을 줄인다.
///
/// lite 모드는 night 모드와 충돌하므로 미니맵은 항상 basic + lite로 둔다.
class MyStoryMapCard extends StatefulWidget {
  /// 내 게시글 목록(좌표 유무 무관 — 내부에서 좌표 있는 것만 마커로).
  final List<BoardPost> posts;

  /// 카드 하단에 표시할 스토리 개수(히어로 카운트와 동일하게 전달).
  final int storyCount;

  /// 카드 탭 콜백(전용 지도 화면으로 이동).
  final VoidCallback onTap;

  const MyStoryMapCard({
    super.key,
    required this.posts,
    required this.storyCount,
    required this.onTap,
  });

  @override
  State<MyStoryMapCard> createState() => _MyStoryMapCardState();
}

class _MyStoryMapCardState extends State<MyStoryMapCard> {
  List<BoardPost> get _located => widget.posts
      .where((p) => p.latitude != null && p.longitude != null)
      .toList();

  Future<void> _onMapReady(NaverMapController controller) async {
    final located = _located;
    if (located.isEmpty) return;

    final icon = await buildStoryMarkerIcon(context, AppColors.of(context));
    if (!mounted) return;

    final markers = located
        .map((p) => NMarker(
              id: 'mystory_${p.boardId}',
              position: NLatLng(p.latitude!, p.longitude!),
              icon: icon,
              size: kStoryMarkerSize,
              anchor: const NPoint(0.5, 0.5),
            ))
        .toSet();
    await controller.addOverlayAll(markers);

    if (located.length == 1) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(located.first.latitude!, located.first.longitude!),
          zoom: 13,
        ),
      );
      return;
    }

    final bounds = NLatLngBounds.from(
      located.map((p) => NLatLng(p.latitude!, p.longitude!)).toList(),
    );
    await controller.updateCamera(
      NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(36)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 184,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 라이브 미니맵 — 비상호작용(AbsorbPointer)으로 카드 전체 탭만 받는다.
            AbsorbPointer(
              child: NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: const NLatLng(37.5666, 126.979), // 서울시청 기본값
                    zoom: 11,
                  ),
                  mapType: NMapType.basic,
                  liteModeEnable: true,
                  scrollGesturesEnable: false,
                  zoomGesturesEnable: false,
                  tiltGesturesEnable: false,
                  rotationGesturesEnable: false,
                  stopGesturesEnable: false,
                  scaleBarEnable: false,
                  logoClickEnable: false,
                  consumeSymbolTapEvents: false,
                ),
                onMapReady: _onMapReady,
              ),
            ),
            // 하단 스크림 + 타이틀 + 화살표 (지도 이미지 위 가독성용 오버레이)
            IgnorePointer(child: _buildOverlay(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay(AppColors colors) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 84,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        decoration: const BoxDecoration(
          // 지도(이미지성) 위 텍스트 가독성을 위한 스크림.
          // 코드베이스의 이미지 카드 스크림 패턴(검정→투명)과 동일.
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.storyCount}개의 스토리',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.95),
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colors.primaryStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
