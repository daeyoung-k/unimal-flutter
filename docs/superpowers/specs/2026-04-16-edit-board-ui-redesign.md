# Edit Board UI Redesign — Design Spec

**Date:** 2026-04-16  
**Status:** Approved  
**File:** `lib/screens/board/edit_board/edit_board.dart`

---

## Goal

`edit_board.dart`(수정하기) 화면을 `add_item.dart`(공유하기)와 동일한 현대적 UI로 업데이트.  
그라디언트 배경, 흰색 카드 레이아웃, 섹션별 입장 애니메이션 적용.

---

## Design System (README 기준)

| 항목 | 값 |
|---|---|
| Primary | `#7AB3FF` |
| Primary Dark | `#3578E5` |
| Gradient Light | `#A8CCFF` |
| 배경 그라디언트 | `#3578E5 → #7AB3FF → #A8CCFF` (위→아래) |
| 카드 radius | `BorderRadius.circular(24)` |
| 카드 색상 | `Colors.white.withValues(alpha: 0.95)` |
| 폰트 | Pretendard |

---

## Screen Structure

```
GestureDetector (onTap → FocusScope.unfocus)
└── Scaffold (resizeToAvoidBottomInset: true)
    └── Container (gradient)
        └── SafeArea
            └── Column
                ├── [Header]        FadeTransition + SlideTransition (top)
                └── Expanded
                    └── SingleChildScrollView (padding: fromLTRB(20,0,20,100))
                        └── Column
                            ├── [Card1] 이미지 섹션
                            ├── [Card2] 제목
                            ├── [Card3] 내용
                            ├── [Card4] 지도 노출 토글
                            └── [Button] 수정 완료
```

---

## Header

- **Layout:** Row (3-slot: left / center / right)
- **Left:** `IconButton(Icons.chevron_left, color: white)` → `Get.back()`
- **Center:** `Text("수정하기", color: white, fontSize: 22, w700, Pretendard)`
- **Right:** `IconButton(Icons.delete_outline, color: white)` → `_confirmDelete()`
- **Animation:** FadeTransition + SlideTransition from `Offset(0, -0.3)`

---

## Card Sections

공통 `_buildCard()` 헬퍼 사용 — add_item.dart와 동일:
```
Container(
  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16)
  decoration: radius 24, white 0.95, boxShadow(blur:16, offset(0,6))
)
```

### Card 1 — 이미지

- 안내 텍스트: "첫 번째 사진이 대표 이미지로 표시돼요." (white70, 13px)
- 가로 스크롤 Row:
  - 추가 버튼: 80×80, radius 20, `Icons.add_rounded` + `N/5` 카운터
  - 기존 이미지 (네트워크): `Image.network`, 80×80, 삭제 버튼(우상단 빨간 원)
  - 신규 이미지 (파일): `Image.file`, 80×80, 삭제 버튼
  - 최대 5장 제한 유지
- **Animation:** card1 (interval 0.15–0.5)

### Card 2 — 제목

- Label: "제목" (grey, 12px, w500)
- TextField: `InputBorder.none`, isDense, hintText
- **Animation:** card2 (interval 0.30–0.65)

### Card 3 — 내용

- Label: "내용" (grey, 12px, w500)
- TextField: `maxLines: 5`, `InputBorder.none`
- **Animation:** card3 (interval 0.45–0.80)

### Card 4 — 지도 노출 토글

- Row: [Column(제목+부제)] + Switch(activeColor: _primary)
- 제목: "지도 노출" (1A1A2E, 15px, w600)
- 부제: "켜두면 내 스토리가 지도에 핀으로 표시돼요." (grey, 12px)
- **Animation:** card3와 같은 애니메이션 그룹

---

## Animation Controllers

add_item.dart와 동일한 5단계 구조:

| 이름 | Interval | 용도 |
|---|---|---|
| headerSlide/Fade | 0.00–0.40 | 헤더 |
| card1Slide/Fade | 0.15–0.50 | 이미지 섹션 |
| card2Slide/Fade | 0.30–0.65 | 제목+내용 카드 |
| card3Slide/Fade | 0.45–0.80 | 위치+토글 카드 |
| btnFade | 0.65–1.00 | 저장 버튼 |

- Duration: 1000ms
- Trigger: `initState`에서 `_ctrl.forward()` 즉시 실행 (push 화면이므로)

---

## Save Button

- add_item 업로드 버튼과 동일한 스타일
- 텍스트: "수정 완료" + `Icons.check_rounded`
- 활성: `Colors.white.withValues(alpha: 0.95)`, foreground: `_primary`
- 비활성: `Colors.white.withValues(alpha: 0.4)`
- `_canSave()` 조건 동일 (제목 + 내용 비어있지 않을 때)

---

## Differences from add_item.dart

| 항목 | add_item | edit_board (신규) |
|---|---|---|
| 헤더 버튼 | 없음 | ← + 🗑 |
| 위치 섹션 | ✅ | ❌ |
| 이미지 소스 | 로컬 파일 | 네트워크 기존 + 로컬 신규 |
| 버튼 텍스트 | "소식 업로드" | "수정 완료" |
| 아이콘 | Icons.send_rounded | Icons.check_rounded |
| 애니메이션 트리거 | didChangeDependencies | initState |
| 초기 데이터 | 빈 폼 | Get.arguments에서 BoardPost 로드 |
