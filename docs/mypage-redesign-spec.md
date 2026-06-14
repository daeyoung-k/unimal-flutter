# 마이페이지 UI 개선 — 구현 위임 문서

> 대상: Claude Code (Flutter `unimal_flutter` 레포)
> 작성 목적: 마이페이지(My 탭) UI 개선 + 스토리 목록 화면 신설을 바로 구현할 수 있게 정리.
> 핵심 원칙: **데이터·라우팅·상세 위젯은 기존 것 재사용. 새로 만드는 건 UI 재구성과 목록 화면뿐.** 오버엔지니어링 금지, 상태관리는 기존 패턴(GetX + setState) 유지.
> 기준 디자인: Figma node `116:261` ("마이페이지 실제 사용 리스트").

---

## 0. 한 줄 요약

`screens/profile/profile.dart`(ProfileScreens, My 탭 랜딩)의 **UI를 카드 기반으로 재구성**하고, **스토리 목록 화면(내 스토리 / 좋아요한 스토리 공용)**을 신설한다. 게시글 상세는 **지도에서 쓰는 바텀 확장 카드를 재사용**한다(`/detail-board` 페이지 푸시 안 함).

메뉴는 **내 스토리 / 좋아요한 스토리** 두 개로 단순화됐다(런닝코스·팔로우는 제외 — 기능 미존재, 추후).

---

## 1. 범위

**한다**
- `ProfileScreens`(`screens/profile/profile.dart`) UI 재구성 — 히어로 카드 / 내 스토리 썸네일 스트립 / 메뉴 리스트 / 더보기 / 빈 상태
- 스토리 목록 화면 신설(공용): **내 스토리** + **좋아요한 스토리** (둘 다 상세 리스트)
- 게시글 카드 타입 분기(이미지 / 텍스트 / 숏츠 placeholder)
- 스토리 탭 시 **바텀 확장 카드(상세+댓글)** 표시 → 재사용 시트 추출(7장)

**안 한다 (추후 별도 태스크)**
- 런닝코스 메뉴/기능 (현재 미존재 — 메뉴에서 제외. 추후 생기면 메뉴 행 추가)
- 팔로우 기능(백엔드 도메인 미존재)
- 숏츠 실제 기능(영상 업로드/재생/썸네일, 미디어 타입)

**좋아요한 스토리 API 상태 (8.2 참고) — ✅ 백엔드 완료**
- 카운트: `GET /board/post/like/stories/total`
- 목록: `GET /board/post/like/stories/list` (액세스 토큰 필수, `page`/`size` 무한 스크롤, 정렬 없음 — 의도)

---

## 2. Figma 참조

- 파일 key: `zL0UifobuW5936gNE5NmZq`
- 노드:
  | 화면 | node-id | 비고 |
  |---|---|---|
  | 마이페이지 (스토리 있음) — **기준** | `116:261` | 메뉴 = 내 스토리·좋아요한 스토리 |
  | 마이페이지 (빈 상태) | `116:383` | 메뉴는 116:261 기준으로 맞출 것 |
  | 스토리 목록(전체보기) | `116:756` | 좋아요한 스토리 목록도 동일 UI |
  | 게시글 카드 타입(이미지/텍스트/숏츠) | `116:532` | |

- Figma MCP 사용 가능하면 각 노드에 `get_design_context` / `get_screenshot`으로 픽셀·간격 확인.
- **충돌 시 Figma(116:261) 우선.**

---

## 3. 디자인 토큰 (중요)

이미 `lib/theme/app_colors.dart`에 `AppColors`(light/dark) 토큰 시스템이 있다. **색은 반드시 `AppColors.of(context)`로 받아 쓰고, 하드코딩(`Color(0xFF...)`) 금지.**

### 3.1 변경 필요
- `AppColors.light.background`: `#FFFFFF` → **`0xFFF7F8FA`** (페이지 회색 배경)
- `AppColors.dark.background`: 유지(`#0F1014`)
- (결정 필요) 좋아요 하트 **코랄(#FF6B6B)** 토큰 부재. 현재 `accent`=주황(`#FF9F43`). → `accentCoral`(light `#FF6B6B` / dark `#FF8585`) 신규 추가 권장.

### 3.2 매핑 (디자인 → 토큰)
| 디자인 요소 | 토큰 |
|---|---|
| 페이지 배경 | `colors.background` |
| 카드 / 표면 | `colors.surface` |
| 카드 테두리 | `colors.border` |
| 행 구분선 | `colors.divider` |
| 히어로 그라데이션 | `[colors.primary, colors.primarySoft]` (light `#3578E5`→`#7AB3FF` — 정확히 일치) |
| 텍스트(제목/본문/메타/약) | `textPrimary` / `textSecondary` / `textTertiary` / `textMuted` |
| 좋아요 하트 코랄 | `accentCoral`(신규) |

- 카드 radius: 메뉴/더보기 카드 18, 히어로 20, 썸네일 14, 목록행 16.
- 폰트: Pretendard(기존).
- `mypage.dart`의 하드코딩 `_primary`/`_primaryDark`도 토큰으로 치환(정리).

---

## 4. 마이페이지 랜딩 구조 (`profile.dart` 재구성)

위→아래 순서. 좌우 패딩 16. 상단 status bar 영역 패딩 확보.

1. **헤더 없음** — "마이페이지" 타이틀/상단 기어 둘 다 없음(의도). 설정은 맨 아래 "더보기"에 있음.
2. **히어로 카드** (그라데이션, radius 20)
   - 좌: 아바타 46 + 카메라 뱃지(`add_a_photo`) → 기존 프로필 이미지 업로드(`_pickAndUploadProfileImage`) onTap 연결
   - 중: 닉네임(16 medium, 흰색) / 팔로워·팔로잉 라인은 **추후** → 지금은 숨기거나 기존 소개글(introduction) 표기
   - 우: 스토리 카운트(`_myPostCount`) + "스토리" 라벨
   - 받은 좋아요 stat·개인정보 버튼 **없음**
3. **내 스토리 섹션**
   - 헤더: "내 스토리" + "전체보기" (→ 6장 목록 화면, mode=myStories)
   - 썸네일 가로 스트립: 높이 128, 카드 100×128, 최신 N개(`_myPosts`), 타입별 카드(5장)
   - **빈 상태**(`_myPosts` 비었음): 스트립 대신 빈 카드 — `place` 아이콘 원형 + "아직 스토리가 없어요" + "발길 닿은 곳의 이야기를 기록해보세요" + **[첫 스토리 남기기]** 버튼(그라데이션) → 공유(add) 화면
4. **메뉴 카드** (surface, 행 = 아이콘칩 + 라벨 + 카운트 + chevron) — **2개만**
   - **내 스토리** (`pin_drop`, 카운트 = `_myPostCount`) → 목록 화면(mode=myStories)
   - **좋아요한 스토리** (`favorite`, 카운트 = 내가 좋아요한 글 수) → 목록 화면(mode=likedStories)
     - ⚠️ 카운트·목록 **API 신설 필요**(8장). 없으면 0/빈 목록으로 표시되고 기능 미동작.
   - ※ 런닝코스·팔로우 목록 **행 없음**(이번 범위 밖).
5. **더보기 카드**
   - 공지사항(`notifications_active`) → 기존 `notice_list`
   - 설정(`settings`) → 기존 `SettingScreen` (개인정보 수정 = 설정 내부)
6. **하단 네비** 유지(기존 `RootScreen` IndexedStack)

**아이콘**(Material Symbols 이름): `pin_drop`, `favorite`, `notifications_active`, `settings`, `arrow_forward_ios`, `place`, `add_a_photo`, `sticky_note_2`, `mode_comment`, `arrow_back_ios_new`. Flutter에서 동일 아이콘으로 매칭.

---

## 5. 게시글 카드 타입 규칙

`BoardPost`에 명시적 타입 필드가 **없다.** 다음으로 추론한다.

- **이미지**: `fileInfoList` 비어있지 않음 → 대표 이미지 `fileInfoList.first.fileUrl`(`CachedNetworkImage`). 핀 + 위치(`streetName`) + 좋아요(`likeCount`) 오버레이.
- **텍스트**: `fileInfoList` 비어있음 → 라이트 카드 + 본문(`content`) 발췌(2줄) + `sticky_note_2` 아이콘. 하단 위치 + 좋아요(어두운 텍스트).
- **숏츠**: **추후.** 미디어 타입 필드 부재 → 지금은 placeholder만. 추후 `board_file.mediaType` 추가 시 분기 + 재생/길이 뱃지.

목록행(6장)에서는 댓글 수(`replyCount`)도 표시.

---

## 6. 스토리 목록 화면 (신규, 공용)

**내 스토리 전체보기**와 **좋아요한 스토리**는 UI가 동일하므로 **하나의 화면을 모드로 재사용**한다.

- 위치: `screens/profile/mypage/story_list.dart`(신규)
- 라우트: `/story-list` (또는 mode 파라미터). 푸시(`Get.toNamed`)
- 모드: `myStories` | `likedStories`
- 구성:
  - 백 헤더: `arrow_back_ios_new` + 제목(모드별 "내 스토리" / "좋아요한 스토리") + 우측 "총 N개"
  - 정렬칩: 최신순 / 좋아요순 / 댓글순 (`_sortType` → `LATEST/LIKE/REPLY`, 기존 `_onSortChanged` 매핑 확인)
  - 상세 리스트(행 카드): 썸네일 84 + 제목 + 위치·날짜(상대시간) + ♥`likeCount` · 💬`replyCount`
- 데이터:
  - myStories → `BoardApiService.getMyPostList({keyword, sortType})`, `getMyPostTotal()` (기존, 페이지네이션 없음)
  - likedStories → 카운트 `getMyLikedTotal()`(`GET /board/post/like/stories/total`), 목록 `getMyLikedPostList({page, size})`(`GET /board/post/like/stories/list`, page/size **무한 스크롤**, 정렬 없음)
- 정렬칩: myStories만 노출, **likedStories는 정렬칩 미표시**(의도, 추후 검색만 추가 예정).
- ⚠️ 무한 스크롤: likedStories는 `ScrollController`로 하단 도달 시 `page++` 추가 로드(중복/마지막 페이지 처리 포함). myStories는 기존대로 단건 조회.
- 상대 시간: `screens/map/bottom_card/relative_time.dart` 재사용
- 하단 네비: 푸시 서브페이지이므로 **백 헤더만, 네비 없이** 권장(Figma 네비는 맥락용). — 최종 결정 확인.

---

## 7. 게시글 상세 — 지도 바텀 확장 카드 재사용

**결정:** 스토리(스트립/목록) 탭 → **지도에서 쓰는 바텀 확장 카드**(상세 + 댓글)를 띄운다. `/detail-board` 페이지 푸시는 쓰지 않는다.

**현실(주의):** `MapBottomCard`(`screens/map/bottom_card/map_bottom_card.dart`)는 지도에 강결합돼 있다.
- 입력 `groups: List<List<MapPost>>` + `initialGroupIndex` (MapPost 기반, 단일 BoardPost 아님)
- 위치/확장 상태를 부모(`map_naver.dart`)가 Stack `Positioned`로 관리
- 마커 좌우 스와이프 등 지도 전용 제스처 포함

→ 목록에서 그대로 재사용 불가. **작은 추출 리팩터 필요**(공짜 아님). 단, 한 번 빼두면 지도/목록이 한 위젯을 공유.

**권장 접근 (단계적)**
1. **재사용 시트 추출:** `PostDetailSheet(boardId)` 신규 위젯
   - 내부는 기존 서브위젯 재사용: `MapCardExpandedContent`(`map_card_expanded_content.dart`), `post_info_section`, 댓글(`screens/board/detail_board/comment/*`), 좋아요 토글(`requestLike`)
   - 표시: `showModalBottomSheet(isScrollControlled: true)` + `DraggableScrollableSheet`로 peek→확장 제스처
   - 입력 `boardId` → `BoardApiService.getBoardDetail(id)` 로 로드
   - 스트립/목록 `onTap` → `PostDetailSheet` 오픈
2. **map_naver는 그대로 둠** (리스크 최소화).
3. **추후/선택:** map의 `MapBottomCard`도 `PostDetailSheet` 기반으로 통일.

**주의:** `MapCardExpandedContent`는 `post(MapPost)` + `detail(BoardPost?)` + `isLoading`을 받는다. MapPost 의존 제거 또는 최소 어댑터 필요. 결합도 확인 후 **최소만** 추출(과한 리팩터 금지).

---

## 8. 재사용 자원 & 신규 API

### 8.1 이미 존재 (재사용 — 새로 만들지 말 것)
- `UserInfoService`: `getMemberInfo`, `updatePersonalInfo`, `checkNickname`, 프로필 이미지 업로드
- `BoardApiService`: `getMyPostList({keyword, sortType})`, `getMyPostTotal()`, `getMyLikeTotal()`(=받은 좋아요 수, 본 작업과 무관), `getBoardDetail(id)`, `requestLike(id)`, 댓글 CRUD
- `NoticeService`: 공지사항
- 위젯/유틸: `relative_time.dart`, `MapCardExpandedContent`, `post_info_section`, `post_image_carousel`, 댓글 위젯, `CachedNetworkImage`
- 라우팅: `app_routes.dart`(GetX). 현재 `profile.dart`는 `Get.toNamed('/detail-board', parameters:{'id': post.boardId})`로 상세를 연다 → 이를 `PostDetailSheet` 오픈으로 교체.

### 8.2 좋아요한 스토리 API (내가 좋아요 누른 게시글)
- **카운트 — ✅ 백엔드 완료**: `GET /board/post/like/stories/total` → 내가 좋아요한 글 수
  - 앱: `BoardApiService.getMyLikedTotal()` = `ApiUri.resolve('board/post/like/stories/total')`
  - 사용처: 메뉴 "좋아요한 스토리" 행의 카운트.
- **목록 — ✅ 백엔드 완료**: `GET /board/post/like/stories/list` → `List<BoardPost>`
  - 인증: 액세스 토큰 필수(기존 `_authHeaders()` 그대로)
  - 쿼리 파라미터(페이지네이션): `page`(default `0`), `size`(default `20`) → **무한 스크롤 지원**
  - **정렬 없음(의도).** likedStories 모드에서는 **정렬칩 미표시**(myStories만 정렬 노출). 추후 검색 정도만 추가 예정.
  - 앱: `BoardApiService.getMyLikedPostList({int page = 0, int size = 20})` 추가, `List<BoardPost>` 반환.

---

## 9. 구현 순서 (권장)

1. `AppColors.light.background` → `#F7F8FA` (+ 필요 시 `accentCoral` 토큰)
2. `profile.dart` 재구성: 히어로 / 스트립 / 메뉴(내스토리·좋아요한스토리) / 더보기 / 빈 상태 — **토큰만 사용**
3. 게시글 카드 위젯 3종(이미지/텍스트/숏츠 placeholder) 분리 (스트립·목록 공용)
4. `/story-list` 공용 목록 화면 + 라우트 (mode: myStories / likedStories)
5. `PostDetailSheet` 추출 + 스트립/목록 `onTap` 연결
6. 좋아요한 스토리 연결(✅ API 완료): 카운트 `getMyLikedTotal()` + 목록 `getMyLikedPostList({page,size})` 무한 스크롤. likedStories 모드는 정렬칩 숨김.
7. `mypage.dart` 하드코딩 색 토큰화(정리)
8. `flutter analyze` 통과 + 라이트/다크 스크린샷 확인

> 백엔드 API는 카운트·목록 모두 완료됨. 앱 작업만 진행하면 됨.

---

## 10. 완료 기준 (검증)

- [ ] `flutter analyze` 0 error
- [ ] 라이트/다크 모드 모두 정상(전부 토큰 기반, 하드코딩 색 없음)
- [ ] 빈 상태 / 채워진 상태 모두 정상 렌더
- [ ] 스토리 탭 → 바텀 확장 카드(상세+댓글) 정상 동작
- [ ] 내 스토리 / 좋아요한 스토리 목록 진입 + 정렬 동작
- [ ] 기존 기능 회귀 없음: 프로필 이미지 업로드, 닉네임/소개 편집, 정렬, 검색, 공지/설정 진입

---

## 11. 추후 별도 태스크 (이번 범위 밖)

- **런닝코스**: 기능 설계 후 메뉴 행 추가(`directions_run`)
- **팔로우**: 백엔드 도메인(팔로워/팔로잉) 신설 후 히어로 팔로워·팔로잉 라인 + 팔로우 목록 메뉴 활성화
- **숏츠**: `board_file.mediaType`(백엔드) + 영상 업로드/썸네일/세로 풀스크린 재생(앱)
- **딥링크 공유**: 필요 시 전체화면 상세 라우트 별도 검토

---

## 부록: 디자인 의도 메모

- 회색 배경(#F7F8FA) + 흰 카드 = 콘텐츠 화면 표준. 로그인/온보딩/공유 같은 **진입·감성 화면은 기존 풀스크린 그라데이션 유지.** 두 세계를 잇는 다리가 히어로 카드 그라데이션.
- 마이페이지는 "허브" 구조 — 기능이 늘면 메뉴 카드에 행 하나 추가하거나, 비중 큰 기능은 섹션(스트립)으로 추가.
