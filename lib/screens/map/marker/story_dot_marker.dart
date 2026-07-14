import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:unimal/screens/map/marker/marker_image_factory.dart';
import 'package:unimal/theme/app_colors.dart';

/// 내 스토리 지도 미리보기(마이페이지 카드 · 우리지도 리스트)의 공용 도트 마커.
///
/// 기본 네이버 핀 대신 화이트 링 + primary 채움의 원형 도트로 통일한다.
/// 라이트/다크(navi) 지도 모두에서 화이트 링이 배경과 분리돼 잘 보인다.
const Size kStoryMarkerSize = Size(26, 26);

/// 마커 아이콘 1장을 만들어 반환한다(모든 마커가 공유 — 뷰당 1회만 생성).
Future<NOverlayImage> buildStoryMarkerIcon(
  BuildContext context,
  AppColors colors,
) {
  // 직렬화 래퍼 경유 — 직접 fromWidget 호출 금지 (marker_image_factory 참고).
  return overlayImageFromWidget(
    context: context,
    size: kStoryMarkerSize,
    widget: _StoryMarkerDot(color: colors.primary),
  );
}

class _StoryMarkerDot extends StatelessWidget {
  final Color color;
  const _StoryMarkerDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: kStoryMarkerSize.width,
      height: kStoryMarkerSize.height,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // 지도(이미지성) 위 마커 분리용 화이트 링 — 양 테마 공통.
        border: Border.all(color: Colors.white, width: 3),
      ),
    );
  }
}
