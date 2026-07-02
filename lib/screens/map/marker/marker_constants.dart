import 'dart:ui' show Size;

import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 지도 마커 시스템 공용 상수.
///
/// 메인 지도(`map_naver.dart`)와 내지도(`my_story_map_screen.dart`)가
/// 같은 마커 시스템을 쓰므로, 크기·폰트·클러스터 동작 값은 반드시
/// 여기서만 정의하고 양쪽에서 공유한다. (화면별로 따로 두면 불일치 발생)

/// 기본 지도 POI 심볼 스케일 — 스토리 마커가 돋보이게 축소.
/// 지도 화면마다 다르면 캡션 폰트가 화면별로 달라 보이는 착시가 생기므로
/// 모든 NaverMap 위젯에 동일하게 적용할 것.
const double kMapSymbolScale = 0.7;

/// 일반(단일) 마커 표시 크기.
const double kNormalMarkerSize = 50.0;

/// 클러스터(2개 이상) 마커 표시 크기 — 메인 지도 썸네일+뱃지 스타일.
const double kClusterMarkerSize = 58.0;

/// 내지도 클러스터 카운트 버블 크기.
const double kClusterBubbleSize = 46.0;

/// 마커 아래 제목 캡션 폰트 크기.
const double kMarkerCaptionTextSize = 19.0;

/// 캡션 제목 최대 글자 수 — 내용을 다 보여주지 않아 눌러보고 싶게 만든다.
const int kMarkerCaptionMaxChars = 5;

/// 클러스터 탭 시 줌인 목표. 클러스터링은 15까지 동작하므로 16이면 겨우
/// 풀리는 수준 — jitter(약 17m) 마커들이 겹쳐 보이지 않게 충분히 당긴다.
const double kClusterExpandZoom = 17.5;

/// 클러스터 병합 거리(화면 dp 기준). "멀리 떨어진 글이 한 클러스터로
/// 묶인다"는 피드백으로 축소된 값 — 100dp는 화면 폭의 1/4 이상이라
/// 체감상 다른 동네 글까지 묶였다.
const Map<NInclusiveRange<int>, double> kClusterMergeDistances = {
  // 줌 0-12 (시·도): 60dp 이내만 묶음
  NInclusiveRange(0, 12): 60.0,
  // 줌 13-14: 50dp
  NInclusiveRange(13, 14): 50.0,
  // 줌 15: 바로 붙어 있는 마커만 40dp
  NInclusiveRange(15, 15): 40.0,
};

/// 텍스트(사진 없는) 글 마커의 줌인 카드 크기 (꼬리 끝 = 하단 중앙).
/// fromWidget size와 NMarker size를 동일하게 — 스케일 왜곡 방지.
const Size kTextCardSize = Size(204, 110);

/// 텍스트 마커/클러스터 탭 시 줌인 목표 (카드가 펼쳐지는 줌).
const double kTextCardCameraZoom = 19.0;

/// 텍스트 마커 표현(점↔카드) 전환 히스테리시스.
/// enter 이상으로 줌인하면 카드로, 그 후 exit 미만으로 줌아웃해야 점으로 복귀.
/// 단일 임계값을 쓰면 파킹 줌과 경계가 겹쳐 카메라 미세 흔들림에 깜빡인다.
const double kTextCardEnterZoom = 17.3;
const double kTextCardExitZoom = 16.8;

/// 캡션용 제목 자르기 — [kMarkerCaptionMaxChars]자 초과 시 말줄임.
String truncateMarkerCaption(String title) => title.length > kMarkerCaptionMaxChars
    ? '${title.substring(0, kMarkerCaptionMaxChars)}…'
    : title;
