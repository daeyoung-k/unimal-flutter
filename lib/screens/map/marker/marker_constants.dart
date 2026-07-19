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

/// score 크기 위계 (피그마 "17 마커 변형 시트" §2).
/// 화면에 로드된 마커들의 score 상대 백분위로 4단계 크기를 정한다.
/// 판정 로직은 `marker_score_tiers.dart` 참고.
const double kMarkerSizeLower = 42.0; // 하위 score
const double kMarkerSizeUpper = 58.0; // 상위 score
const double kMarkerSizeHot = 66.0; // 핫플 (상위 5%) + 캡션 우선권

/// score 위계 백분위 경계.
const double kMarkerTierHotPercentile = 0.95;
const double kMarkerTierUpperPercentile = 0.75;
const double kMarkerTierLowerPercentile = 0.25;

/// 위계를 적용할 최소 마커 수 — 표본이 적으면 전부 기본 크기.
/// (마커 3개 중 1개가 "핫플"이 되는 왜곡 방지)
const int kMarkerTierMinSample = 8;

/// 마커 링(테두리) 두께 — 표시 dp 기준 (피그마 §1: 화이트 링 4px).
/// 비트맵 캔버스(200px)에는 `4 * 200 / kNormalMarkerSize` 로 환산해 그린다.
const double kMarkerRingWidthDp = 4.0;

/// "새 글" 링(accent) 유지 시간 — 작성 후 24시간 (피그마 §1).
const Duration kNewPostRingDuration = Duration(hours: 24);

/// 클러스터(2개 이상) 마커 표시 크기 — 메인 지도 썸네일+뱃지 스타일.
const double kClusterMarkerSize = 58.0;

/// 선택된 사진 마커 확대 배율.
///
/// 선택 표현은 z-index 부스트 + setSize 확대만 사용한다. 아이콘 재합성
/// (링 오버레이 등)은 iOS 마커 이미지 캐시 경합 크래시 이력 때문에 배제 —
/// setSize는 비트맵을 다시 만들지 않아 캐시/경합 리스크가 없다.
/// 텍스트 카드 마커(가변 크기)에는 적용하지 않는다.
const double kSelectedMarkerScale = 1.18;

/// 내지도 클러스터 카운트 버블 크기.
const double kClusterBubbleSize = 46.0;

/// 마커 아래 제목 캡션 폰트 크기.
const double kMarkerCaptionTextSize = 19.0;

/// 캡션 제목 최대 글자 수 — 내용을 다 보여주지 않아 눌러보고 싶게 만든다.
/// (피그마 확정안: 기본 8자 말줄임. 선택 마커는 전체 타이틀 노출 — 별도 처리)
const int kMarkerCaptionMaxChars = 8;

/// 선택(포커스) 마커의 전체 타이틀 캡션 랩 폭(dp).
/// 피그마 18-2 ⑤: 선택 마커는 전체 타이틀 노출 — requestedWidth 로 2~3줄 랩.
const double kSelectedMarkerCaptionWidth = 110.0;

/// 단일 마커 선택 시 줌인 목표. 인접 마커들이 겹쳐 보이지 않게 당긴다.
/// (같은 좌표 다중 글은 jitter 대신 스택 마커로 유지 — A안)
const double kClusterExpandZoom = 17.5;

/// 클러스터(임시 묶음) 탭 시 줌인 목표 — 카드 없이 카메라만 이동해 펼친다.
/// 17.5에선 10~20m 간격 스택들이 여전히 포개져 보여 18로 더 당긴다
/// (2026-07-13 피드백). 클러스터링은 16까지라 이 줌에선 확실히 풀림.
const double kClusterTapZoom = 18.0;

/// 스택 원형 펼침 (피그마 "15 B안 — 탭하면 부채꼴 펼침").
/// 스택 마커 탭 → 이 줌까지 당긴 뒤 글들을 실제 좌표 중심 원형으로 펼친다.
/// 점선 다리 = 실제 좌표 표시, 지도 이동/지도 탭 시 다시 접힘.
const double kStackFanZoom = 19.0;

/// 펼침 원 기본 반지름(dp). 글 수가 많으면 서로 겹치지 않게 자동 확대 —
/// 원주(2πr)가 `글 수 × (마커 50dp + 간격)` 이상이 되도록.
const double kStackFanBaseRadiusDp = 70.0;
const double kStackFanMarkerGapDp = 14.0;

/// 점선 다리 패턴 (dp): 선 6 - 공백 4.
const List<int> kStackFanLegPattern = [6, 4];

/// 펼침 중심점(실제 위치) 강조 — GPS 현재위치 스타일 이중 원.
/// 점(진한 primary + 화이트 링) 위에 연한 할로를 넓게 깔아 시선을 모은다.
/// (기존 3.5dp 단일 점은 "어디가 정확한 위치인지 모르겠다" 피드백 — 2026-07-13)
const double kStackFanCenterDotRadiusDp = 6.0;
const double kStackFanCenterHaloRadiusDp = 18.0;

/// 클러스터 병합 거리(화면 dp 기준). "멀리 떨어진 글이 한 클러스터로
/// 묶인다"는 피드백으로 축소된 값 — 100dp는 화면 폭의 1/4 이상이라
/// 체감상 다른 동네 글까지 묶였다.
const Map<NInclusiveRange<int>, double> kClusterMergeDistances = {
  // 줌 0-12 (시·도): 60dp 이내만 묶음
  NInclusiveRange(0, 12): 60.0,
  // 줌 13-14: 50dp
  NInclusiveRange(13, 14): 50.0,
  // 줌 15-16: 바로 붙어 있는(화면상 겹치는) 마커만 40dp.
  // 16 포함 이유: 기본 진입 줌(16.5)에서 인접 스택 마커 포개짐 해소
  // (2026-07-13 — 서울역 +4/+2 스택 겹침 피드백).
  NInclusiveRange(15, 16): 40.0,
};

/// 텍스트(사진 없는) 글 마커의 줌인 카드 비트맵 크기.
/// 확정안: 카드(고정 폭 204, 본문 폭 180) + 4px 간격 + 점 앵커(꼬리 끝 = 하단 중앙).
/// 폭 220 = 카드 204 + 그림자(blur 8) 여유. 높이 130 = 카드(제목+본문2줄 ≈ 77)
/// + 간격 4 + 점 39 + 상단 그림자 여유. bottomCenter 정렬이라 남는 공간은 투명.
/// fromWidget size와 NMarker size를 동일하게 — 스케일 왜곡 방지.
const Size kTextCardSize = Size(220, 130);

/// 텍스트 마커/클러스터 탭 시 줌인 목표 (카드가 펼쳐지는 줌).
const double kTextCardCameraZoom = 19.0;

/// 텍스트 마커 표현(점↔카드) 전환 히스테리시스.
/// enter 이상으로 줌인하면 카드로, 그 후 exit 미만으로 줌아웃해야 점으로 복귀.
/// 단일 임계값을 쓰면 파킹 줌과 경계가 겹쳐 카메라 미세 흔들림에 깜빡인다.
/// 17.3/16.8 → 16.8/16.3 으로 하향 (2026-07-19) — 더 줌아웃된 높이에서도
/// 말풍선 표시. 하한 주의: 클러스터링 구간(≤16, enableZoomRange)과 겹치면
/// 클러스터 위에 말풍선이 뜨므로 exit 는 16 초과를 유지할 것.
const double kTextCardEnterZoom = 16.8;
const double kTextCardExitZoom = 16.3;

/// 말풍선 레이어 페이드 인/아웃 시간 (2-레이어 설계 docs/specs/2026-07-19).
/// 일반 NMarker 전용 alpha 트윈 — 클러스터러블에는 사용 금지 (payload 되돌림).
const Duration kBubbleFadeDuration = Duration(milliseconds: 200);

/// 같은 자리 스택(A안) 그룹핑 좌표 정밀도 — 소수점 자리 수.
/// 4자리 = 위경도 약 11m 타일. "같은 자리"(같은 가게·같은 지점)만 스택으로
/// 묶고, 그 이상 떨어진 글은 개별 마커로 지도에 그대로 보여준다.
/// (3자리(≈110m)로 묶으면 다른 장소 글까지 한 스택에 빨려 들어가
/// "클러스터가 안 펼쳐진다"로 체감됨 — 2026-07-13 피드백)
const int kStackGroupPrecision = 4;

/// 클러스터 병합/분리 애니메이션 (메인 지도·내지도 공용).
/// Duration.zero(끄기)로 두던 것을 300ms 로 복원 (2026-07-16) — 줌아웃 시
/// 마커가 순간이동으로 합쳐져 "뚝뚝 끊기는" 체감의 원인이었다.
/// 과거 끈 이유였던 카운트업 잔상은 이제 별도 방어가 담당한다:
/// 메인 지도 = _composeClusterIconAsync 의 300ms 안정화 + stale 체크,
/// 내지도 = 버블 target count 가드. 300ms 는 그 안정화 대기와 정렬된 값.
const Duration kClusterAnimationDuration = Duration(milliseconds: 300);

/// 밀집 지역 판정 (피그마 §4 C안: 밀집 지역에선 카드 대신 점 고정).
/// **화면 dp 기준** — 반경 [kTextCardDenseRadiusDp] 안에 다른 마커 그룹이
/// [kTextCardDenseNeighbors]개 이상이면 텍스트 카드로 펼치지 않는다.
/// (204dp 카드가 겹겹이 쌓여 지도를 가리는 문제 방지)
///
/// 고정 위경도(0.0005deg ≈ 55m) 기준이던 것을 dp 로 변경 (2026-07-15):
/// 지리 고정 반경은 줌 19+ 에서 화면 반대편 마커까지 "밀집"으로 잡아
/// 줌인할수록 말풍선이 점으로 강제되는 역전이 있었다. 120dp 는 기존
/// 값이 튜닝된 줌(≈17.8, 55m ≈ 120dp)에서 동일 동작을 보존한다.
const double kTextCardDenseRadiusDp = 120;
const int kTextCardDenseNeighbors = 2;

/// 캡션용 제목 자르기 — [kMarkerCaptionMaxChars]자 초과 시 말줄임.
String truncateMarkerCaption(String title) => title.length > kMarkerCaptionMaxChars
    ? '${title.substring(0, kMarkerCaptionMaxChars)}…'
    : title;
