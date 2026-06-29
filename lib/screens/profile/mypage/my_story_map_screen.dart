import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/profile/mypage/post_detail_sheet.dart';
import 'package:unimal/screens/profile/mypage/story_marker.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/theme/app_colors.dart';

/// 내 스토리 전용 지도 화면.
///
/// 메인 지도 탭과 달리 **내 글만** 마커로 표시한다. 마커 탭 시 상세 시트를 띄운다.
/// 마이페이지 지도 미리보기 카드(`MyStoryMapCard`) 탭으로 진입.
class MyStoryMapScreen extends StatefulWidget {
  const MyStoryMapScreen({super.key});

  @override
  State<MyStoryMapScreen> createState() => _MyStoryMapScreenState();
}

class _MyStoryMapScreenState extends State<MyStoryMapScreen> {
  final _boardApi = BoardApiService();

  List<BoardPost> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final posts = await _boardApi.getMyPostList(sortType: 'LATEST');
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    }
  }

  List<BoardPost> get _located =>
      _posts.where((p) => p.latitude != null && p.longitude != null).toList();

  Future<void> _onMapReady(NaverMapController controller) async {
    final located = _located;
    if (located.isEmpty) return;

    final icon = await buildStoryMarkerIcon(context, AppColors.of(context));
    if (!mounted) return;

    final markers = <NMarker>{};
    for (final p in located) {
      final marker = NMarker(
        id: 'mystory_${p.boardId}',
        position: NLatLng(p.latitude!, p.longitude!),
        icon: icon,
        size: kStoryMarkerSize,
        anchor: const NPoint(0.5, 0.5),
      );
      marker.setOnTapListener((NMarker _) {
        if (mounted) showPostDetailSheet(context, p.boardId);
      });
      markers.add(marker);
    }
    await controller.addOverlayAll(markers);
    await _fitCamera(controller, located);
  }

  Future<void> _fitCamera(
      NaverMapController controller, List<BoardPost> located) async {
    if (located.length == 1) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(located.first.latitude!, located.first.longitude!),
          zoom: 14,
        ),
      );
      return;
    }

    final pad = MediaQuery.paddingOf(context);
    final bounds = NLatLngBounds.from(
      located.map((p) => NLatLng(p.latitude!, p.longitude!)).toList(),
    );
    await controller.updateCamera(
      NCameraUpdate.fitBounds(
        bounds,
        padding: EdgeInsets.only(
          top: pad.top + 72,
          bottom: 72,
          left: 56,
          right: 56,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: const NLatLng(37.5666, 126.979),
                zoom: 11,
              ),
              mapType: isDark ? NMapType.navi : NMapType.basic,
              nightModeEnable: isDark,
              consumeSymbolTapEvents: false,
            ),
            onMapReady: _onMapReady,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(colors),
          ),
          if (_isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: colors.background.withValues(alpha: 0.55),
                child: Center(
                  child: CircularProgressIndicator(
                      color: colors.primaryStrong, strokeWidth: 2),
                ),
              ),
            ),
          if (!_isLoading && _located.isEmpty) _buildEmpty(colors),
        ],
      ),
    );
  }

  Widget _buildTopBar(AppColors colors) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
        child: Row(
          children: [
            _circleButton(
              colors: colors,
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Get.back(),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '내 지도',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Pretendard',
                      color: colors.textPrimary,
                    ),
                  ),
                  if (!_isLoading) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${_located.length}개',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required AppColors colors,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: colors.textPrimary),
      ),
    );
  }

  Widget _buildEmpty(AppColors colors) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined, size: 40, color: colors.textMuted),
            const SizedBox(height: 12),
            Text(
              '지도에 표시할 스토리가 없어요',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard',
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '위치가 담긴 스토리를 남기면 여기에 모여요',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Pretendard',
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
