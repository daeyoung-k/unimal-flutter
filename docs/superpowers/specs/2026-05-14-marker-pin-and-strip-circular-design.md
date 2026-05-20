# 선택 마커 핀 변환 + 스트립 원형 아바타화

> 작성일: 2026-05-14
> 관련 파일:
> - `lib/screens/map/map_naver.dart`
> - `lib/service/image/image_service.dart`
> - `lib/screens/map/bottom_card/map_thumbnail_strip.dart`

## 배경

지도 마커 / 미리보기 스트립 / 카드 세 영역 모두에 같은 콘텐츠 이미지가 노출되어 시각적 중복이 강함. 사용자는 셋의 역할을 분리하고 싶어함:

- **마커**: "이 사진이 찍힌 정확한 장소"를 가리키는 위치 인디케이터
- **스트립**: 카드가 가리는 다른 마커의 콘텐츠를 빠르게 슬라이드하며 인덱싱
- **카드**: 선택된 콘텐츠의 풀 이미지 + 본문

이 분리를 가벼운 단계로 시작:
1. **선택된 마커**를 사진 마커에서 단색 푸른 핀으로 즉시 교체 → "위치 강조" 의미 + 카드와의 이미지 중복 해소
2. **스트립 썸네일을 원형 아바타로** → 마커(원형 이미지)와의 시각 일체화로 "다른 마커의 후보들"이라는 맥락을 명확히

당근 동네지도의 마커 디자인(티어드롭 솔리드 + 가운데 점 + 외곽선 없음)이 시각적 참고. 컬러만 우리 브랜드 푸른색으로 차별화.

## 설계

### 1. 핀 이미지 생성

`ImageService.createPinMarkerImage()` 추가:

- 모양: 티어드롭 핀 (위쪽 원형 머리 + 아래쪽 뾰족 꼬리). `Canvas` + `Path` 로 그림
- 컬러: `Color(0xFF3578E5)` 단색 솔리드
- 가운데 점: 흰색 작은 원 (반지름 약 5px, 머리 중심)
- 외곽선: 없음
- 그림자: 살짝 (Canvas `drawShadow` 또는 별도 paint, blur ~4, 검정 25% opacity, offset Y +2)
- 사이즈: 36×46 (px). 일반 마커 32보다 약간 크게 → 두드러짐
- 출력: `Uint8List` (PNG bytes)

핀은 모든 선택 마커가 공유하는 정적 디자인이라 1번만 생성하고 캐시.

### 2. 마커 선택/해제 시 핀 토글

`map_naver.dart` 의 `_applySelectionHighlight(String?)` 확장:

- 진입 시 핀 `NOverlayImage` lazy init (한 번만)
- 마커 선택:
  - `marker.setIcon(pinImage)`
  - `marker.setSize(Size(36, 46))`
  - `marker.setAnchor(NPoint(0.5, 1.0))` (bottom-center: 핀 끝이 좌표 정확히 지목)
  - `marker.setGlobalZIndex(_selectedMarkerZIndex)` (기존)
- 마커 해제 (이전 선택 마커가 있을 때):
  - `marker.setIcon(_markerIconCache[id])` (원래 사진 아이콘 복원)
  - `marker.setSize(Size(_normalMarkerSize, _normalMarkerSize))` (32×32)
  - `marker.setAnchor(NPoint.relativeCenter)` (기존 default)
  - `marker.setGlobalZIndex(_markerBaseZIndex[id])` (기존)
- 트리거 위치는 이전 작업 그대로 (마커 탭 / onGroupChanged / onClose / _closeAllCards / _onSymbolTapped / 재조회 후 복원).

### 3. 스트립 썸네일 원형 마스크

`map_thumbnail_strip.dart` 의 썸네일 컨테이너:

- 현재 사각/라운드 사각 → `ClipOval` 또는 `BorderRadius.circular(반지름)` 로 원형 마스크
- 사이즈는 현재 그대로
- 별도 텍스트(제목/캡션) 추가 안 함 (현재 상태 유지)
- 선택 칸 가운데 정렬, 선택 강조 표시 등 기존 UX 유지

## Edge cases

- 핀 이미지 생성 실패 시: 해당 선택은 z-index 부스트만 적용하고 핀 변환은 스킵 (방어).
- 선택된 마커가 재조회로 사라지면: 기존 처리(`_highlightedMarkerId = null`)로 자동 해제. 새 영역에 같은 ID 마커가 다시 나타나면 `_loadMapMarkersInternal` 끝의 highlight 재적용 로직이 핀으로 다시 변환.
- 클러스터에 묶인 상태(줌 14 이하)에서 발생하는 케이스: 직전 작업으로 카드/스트립 진입 시 줌 15+ 보장 → 발생 가능성 거의 없음.

## 비변경 영역

- 일반(미선택) 마커의 사진 아이콘, 크기(32), anchor — 그대로
- 클러스터 마커 디자인 (사진 아이콘 + 우상단 +N 코랄 뱃지) — 그대로
- 줌 정책, 클러스터링 정책, 클러스터 탭 자동 확대 — 그대로
- 카드 디자인 — 그대로
- 스트립의 선택 인디케이터/스크롤 동작 — 그대로 (시각 마스크만 변경)

## 후속 작업 후보 (이번 범위 밖)

- 핀에 카테고리 아이콘 통합 (현재는 가운데 흰 점만)
- 코랄 클러스터 뱃지 컬러를 브랜드 푸른색 계열로 통일 (별도 디자인 결정)
- 정식 `AppColors` 정의 + 흩어진 `_primary` 통합
