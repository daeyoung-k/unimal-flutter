# 지도 바텀시트 카드 UI 리뉴얼 — 설계 문서

- **작성일**: 2026-05-13
- **로드맵 위치**: 1️⃣ 지도 바텀시트 UX 개선 (스토맵 메인 피드화의 핵심)
- **대상 모듈**: `unimal-flutter` (Flutter 앱)
- **백엔드 변경**: 없음 (응답 DTO는 이미 `file_info_list` 마이그레이션 완료)

## 1. 목표

지도 핀 탭 시 표시되는 바텀시트를 "이미지 중심의 큰 카드 + 좌우 이미지 캐러셀 + 상하 게시글 순회"로 리뉴얼한다. 스토맵의 차별점인 "지도 위에서 이야기를 발견하고 소비하는 SNS"를 첫 화면에서 전달하는 것이 핵심이다.

## 2. 범위

### 포함
- 바텀시트 2단계 스냅 포인트 (peek 30% / full 55%)
- `file_info_list` 좌우 스와이프 이미지 캐러셀 + 도트/페이지 인디케이터
- 상하 스와이프로 게시글 전환 (같은 좌표 우선 → 다른 마커 순회)
- 다른 마커로 전환 시 지도 카메라 부드럽게 이동
- 상대 시간 표시 ("5분 전" / "2시간 전" / "3일 전" 등)
- 큰 "자세히 보기" 액션 버튼 → `/detail-board`

### 제외 (별도 작업으로 분리)
- 북마크 / 저장 기능 (백엔드 미구현)
- 더보기 메뉴 ⋮ (신고/공유/숨김)
- 마커 디자인 리뉴얼 (원형 썸네일·그룹 카운트 배지)
- 상단 검색창 통합 검색 확장 (로드맵 4️⃣)
- 친구 / 본인글 마커 테두리 색상 (로드맵 5️⃣)
- score 식 본인글 +10,000 보너스 제거 (로드맵 3️⃣)

## 3. 확정된 결정 사항

| # | 결정 | 선택 |
|---|------|------|
| 1 | 스냅 포인트 | **2단계** (peek 30% / full 55%) |
| 2 | "다음 게시글" 기준 | **같은 좌표 우선 → 다른 마커** (그룹 단위 순회) |
| 3 | 백엔드 미구현 항목 | **완전 제외** (북마크/더보기) |
| 4 | full 상태 제스처 | 좌우 = 이미지 캐러셀, 위 = 다음 게시글, 아래 = 이전 게시글, 핸들 탭 = 닫기 |
| 5 | 구현 접근 방식 | 기존 위젯 확장 (Positioned + AnimatedContainer + GestureDetector 수동 제어). `DraggableScrollableSheet` 미사용 — 내부 PageView와 제스처 충돌 회피 목적 |

## 4. 컴포넌트 구조

```
lib/screens/map/
├── map_naver.dart                  — 마커 탭 핸들러 + 카드 진입점 (기존 _BottomCard 위젯 제거)
└── bottom_card/                    ← 신규 폴더
    ├── map_bottom_card.dart         — 시트 컨테이너. peek/full 상태, 그룹 인덱스, 제스처 라우터
    ├── post_image_carousel.dart     — 좌우 PageView. file_info_list 표시
    ├── post_info_section.dart       — 제목·주소·시간·내용·좋아요·댓글·자세히보기 버튼
    └── relative_time.dart           — created_at → 상대 시간 헬퍼
```

### 4.1 책임 분담

- **`MapBottomCard`** (Stateful)
  - 입력: `List<List<MapPost>>` (좌표별 그룹 리스트), 초기 그룹/게시글 인덱스, `onCameraMove(NLatLng)` 콜백, `onClose()` 콜백
  - 내부 상태: `SheetState(peek|full)`, `currentGroupIndex`, `postIndexInGroup`, `currentImageIndex`
  - 제스처 라우팅: peek↔full, 닫기, 다음/이전 게시글
  - 외부 효과: 다른 그룹으로 점프 시 `onCameraMove` 호출

- **`PostImageCarousel`** (Stateful)
  - 입력: `List<FileInfo>`, `int currentIndex`, `ValueChanged<int> onChanged`
  - 좌우 PageView + 우상단 `N / total` 뱃지 + 하단 도트 인디케이터
  - `PageView`의 `physics: ClampingScrollPhysics()` — 끝에서 멈춤. 부모 상하 제스처와 충돌 없음

- **`PostInfoSection`** (Stateless)
  - 입력: `MapPost post`
  - 표시: 제목, 주소(아이콘 + 도로명), 상대 시간, 내용, 좋아요·댓글 카운트, "자세히 보기" 큰 버튼
  - 액션: "자세히 보기" → `Get.toNamed('/detail-board', parameters: {'id': post.id})`
  - 좋아요는 카운트 표시만 (토글은 상세 화면에서)

- **`relativeTime(DateTime created)`** (top-level 함수)
  - 출력 규칙: `< 1분 → "방금 전"`, `< 60분 → "N분 전"`, `< 24시간 → "N시간 전"`, `< 7일 → "N일 전"`, 그 외 `"YYYY-MM-DD"`
  - 파싱 실패 시 `"방금 전"` fallback

## 5. 상태 / 데이터 흐름

```
[마커 탭 (markerId)]
   │
   ▼
MapNaverScreens._handleMarkerTap(markerId)
   ├─ 전체 응답을 좌표 기준으로 grouped (이미 map_naver.dart:165~169 로직 존재)
   ├─ 탭한 마커의 그룹 인덱스 찾기 → initialGroupIndex
   └─ MapBottomCard 표시 (또는 기존 카드 상태 갱신)
       │
       ▼
   내부 next() / prev() 로직:
   ─────────────────────────────────────
   next():
     if postIndexInGroup + 1 < groups[currentGroupIndex].length:
         postIndexInGroup++              ── 같은 좌표 내 (카메라 고정)
     elif currentGroupIndex + 1 < groups.length:
         currentGroupIndex++
         postIndexInGroup = 0
         currentImageIndex = 0
         onCameraMove(groups[currentGroupIndex].first.position)
     else:
         (멈춤, 약한 bounce 피드백 50ms)

   prev():
     if postIndexInGroup > 0:
         postIndexInGroup--               ── 같은 좌표 내 (카메라 고정)
     elif currentGroupIndex > 0:
         currentGroupIndex--
         postIndexInGroup = groups[currentGroupIndex].length - 1
         currentImageIndex = 0
         onCameraMove(groups[currentGroupIndex].first.position)
     else:
         (멈춤, 약한 bounce 피드백 50ms)
```

**카메라 이동**: `flutter_naver_map`의 `NaverMapController.updateCamera(NCameraUpdate.fromCameraPosition(...).animation(NCameraAnimation.fly, duration: Duration(milliseconds: 600)))` 사용.

**상태 격리**: `MapBottomCard`는 자체 인덱스 상태만 보유. 게시글 데이터는 부모로부터 immutable list로 받음 (외부 갱신 시 `didUpdateWidget`에서 인덱스 보정).

## 6. 제스처 매트릭스

| 상태 | 제스처 | 동작 | 카메라 |
|------|--------|------|--------|
| peek | 위 드래그 (≥ 60px) | peek → full | 고정 |
| peek | 아래 드래그 (≥ 60px) | 닫기 | 고정 |
| peek | 카드 영역 탭 | peek → full | 고정 |
| peek | 핸들 탭 | 닫기 | 고정 |
| full | 좌 스와이프 | 같은 게시글 다음 이미지 (끝이면 멈춤) | 고정 |
| full | 우 스와이프 | 같은 게시글 이전 이미지 (시작이면 멈춤) | 고정 |
| full | 위 스와이프 (velocity ≥ 300 px/s **또는** drag ≥ 80px) | 다음 게시글 (next 로직) | 그룹 끝이면 이동 |
| full | 아래 스와이프 (동일 임계값) | 이전 게시글 (prev 로직) | 그룹 처음이면 이동 |
| full | 핸들 탭 | 닫기 | 고정 |

### 충돌 해결
- `PostImageCarousel`의 가로 `PageView`는 `ClampingScrollPhysics` — 끝에서 부모로 전파되지 않음 (의도된 멈춤).
- 상하 제스처는 `MapBottomCard`의 최상위 `GestureDetector(onVerticalDragEnd:)`에서 받음. `PageView`는 수평만 흡수하므로 충돌 없음.
- peek/full 전환은 같은 `onVerticalDragEnd` 핸들러에서 상태에 따라 분기.

### 경계 조건
- 첫 그룹 첫 게시글에서 prev → 약한 bounce (50ms 위로 살짝 튕김), 더 이상 이동 없음.
- 마지막 그룹 마지막 게시글에서 next → 동일.
- 빈 그룹 리스트(이론상 불가) → 카드 표시 생략.

## 7. 에러 처리

| 상황 | 처리 |
|------|------|
| 빈 `file_info_list` | placeholder (회색 배경 + `Icons.image_outlined`). 카드는 정상 표시 |
| 이미지 로드 실패 | `CachedNetworkImage.errorWidget` → 같은 placeholder |
| 마커 탭 시 그룹 비어있음 | 카드 표시 생략, debug print |
| `created_at` 파싱 실패 | "방금 전" fallback |
| 좌우/상하 끝 도달 | 시각 멈춤만, 에러 아님 |
| 카드 표시 중 다른 그룹의 마커 탭 | 해당 그룹으로 전환, 인덱스 리셋(0/0), 카메라 이동 |
| 카드 표시 중 현재 그룹의 마커 다시 탭 | 인덱스 유지 (no-op) |
| "닫기" 동작 | 시트 위젯만 사라짐, 지도/카메라 상태는 그대로 유지 |

상위 단계의 API 실패(`/board/map/location/post`)는 카드 책임 아님 — 기존 처리 유지.

## 8. 테스트 전략

스토맵의 1인 풀스택·빠른 출시 우선 성격을 반영한 **YAGNI 최소 테스트**.

| 레벨 | 대상 | 추가 |
|------|------|------|
| 단위 | `relativeTime(DateTime)` 헬퍼 | ✅ 추가. 시간 경계값(59초/60초/59분/60분/23시간/24시간/6일/7일) |
| 단위 | next/prev 그룹 순회 로직 | ✅ 추가. 빈 그룹/단일 그룹/끝 도달 케이스 |
| 위젯 | 제스처 분기 | ❌ 디바이스 직접 확인이 더 효율 |
| 통합 | 카드 → 다음 게시글 흐름 | ❌ 동일 사유 |

테스트 위치: `test/screens/map/bottom_card/` (신규).

## 9. 작업 외 영향

- 기존 `_BottomCard` 위젯 (map_naver.dart 내 ~820~1013줄) **삭제**.
- `map_naver.dart`의 마커 탭 핸들러는 새 `MapBottomCard` 진입점으로 교체.
- 새 디렉터리 `lib/screens/map/bottom_card/` 생성.
- `relative_time.dart`는 두 번째 사용처가 생기면 `lib/utils/`로 이동 (현 시점에선 `bottom_card/` 내).
- `pubspec.yaml` 의존성 변경 없음 (`flutter_naver_map`, `cached_network_image`, `get` 기존 사용).

## 10. 의존성 / 참고

- 백엔드 응답 DTO: 본 작업 시점 이미 `file_info_list` 배열 + `isOwner`로 마이그레이션 완료.
- 카메라 이동 API: `flutter_naver_map` `NaverMapController.updateCamera` 사용.
- 이미지 캐시: `cached_network_image` 기존 사용 — 좌우 스와이프 시 자동 캐시 활용.
- 라우팅: `Get.toNamed('/detail-board', parameters: {'id': post.id})` 기존 패턴 유지.

## 11. 메모리 / 노션 동기화 (구현 후)

작업 완료 시:
- 노션 페이지 1️⃣ 체크리스트에 ✅ 이미지 카드 / ✅ 상하 스와이프 / ✅ 카메라 이동 추가
- 메모리 `stomap-roadmap-priorities` 1️⃣ 항목 진행률 갱신
- 메모리 `stomap-gesture-semantics` "현재 구현과 충돌" 경고 제거
