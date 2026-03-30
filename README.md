# 스토맵 (Stomap)

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/GetX-8B1538?style=for-the-badge&logo=getx&logoColor=white" alt="GetX">
</p>

## 📱 프로젝트 소개

**스토맵(Stomap)** 은 지도 위에 나만의 이야기를 핀으로 남기고, 주변 사람들과 공유하는 위치 기반 스토리 공유 앱입니다.

> "지도 위에 당신의 이야기를 남기세요"

### 🎯 주요 특징

- **📍 위치 기반 스토리**: 현재 위치에 스토리를 핀으로 등록하고 지도에 노출
- **💬 커뮤니티 게시판**: 스토리 피드, 좋아요, 댓글/대댓글
- **🔐 소셜 로그인**: 카카오, 네이버, 구글 간편 로그인 지원
- **🎨 브랜드 디자인**: 파란 핀 + 코랄 포인트 컬러의 일관된 UI

---

## 🎨 디자인 시스템

### 브랜드 컬러
| 역할 | 색상 | HEX |
|---|---|---|
| Primary | 메인 블루 | `#7AB3FF` |
| Primary (Nav Active) | 진한 블루 | `#5B9FEF` |
| Primary Dark | 딥 블루 | `#3578E5` |
| Accent | 코랄 레드 | `#FF6B6B` |
| Background Light | 연한 블루 | `#E8F2FF` |
| Gradient Light | 밝은 블루 | `#A8CCFF` |

### 그라디언트
- **화면 배경** (로그인/공유하기/프로필): `#3578E5` → `#7AB3FF` → `#A8CCFF` (위→아래, 위가 진하게)
- **버튼**: `#3578E5` → `#5B9FEF` (위→아래)

### 타이포그래피
- **기본 폰트**: Pretendard
- **앱 이름**: `w800`, 32px, white

### 공통 컴포넌트
- 카드: `BorderRadius.circular(24)`, `Colors.white.withOpacity(0.95)`, 부드러운 그림자
- 버튼: `BorderRadius.circular(14)`, 그라디언트 적용
- 로그인 버튼: `BorderRadius.circular(14)`, height 54

---

## 📂 주요 화면 구조

```
lib/screens/
├── auth/login/
│   └── login.dart              # 메인 로그인 화면 (소셜 + 이메일)
│       └── widget/
│           └── manual_login_form.dart
├── add/
│   └── add_item.dart           # 스토리 공유하기 화면
├── board/
│   ├── board.dart              # 게시판 피드
│   └── widget/
├── navigation/
│   ├── root_screen.dart        # 하단 네비게이션 + IndexedStack
│   └── app_routes.dart         # 라우트 정의
├── profile/
│   ├── profile.dart            # 내 프로필 (스탯카드 + 내 스토리)
│   ├── mypage/mypage.dart      # 개인정보 수정
│   └── setting/setting.dart    # 설정
└── map/                        # 지도 화면
```

---

## 🛠 기술 스택

### Frontend
- **Framework**: Flutter 3.6.1+
- **Language**: Dart
- **상태관리**: GetX 4.7.2
- **네비게이션**: GetX Router

### 주요 라이브러리
```yaml
dependencies:
  # UI/UX
  flutter_native_splash: ^2.4.4    # 스플래시 화면
  flutter_svg: ^2.0.17             # SVG 이미지 지원

  # 지도 & 위치
  google_maps_flutter: ^2.12.3     # Google Maps 통합
  geolocator: ^11.0.0              # 위치 정보 획득

  # 인증
  kakao_flutter_sdk: ^1.9.6        # 카카오 로그인
  naver_login_sdk: ^2.3.0          # 네이버 로그인
  google_sign_in: ^6.3.0           # 구글 로그인

  # 데이터 & 보안
  http: ^1.3.0                     # HTTP 통신
  flutter_secure_storage: ^9.2.4   # 안전한 데이터 저장
  flutter_dotenv: ^5.2.1           # 환경변수 관리

  # 유틸리티
  image_picker: ^1.0.7             # 이미지 선택
  permission_handler: ^11.3.0      # 권한 관리
  logger: ^2.5.0                   # 로깅

dev_dependencies:
  flutter_launcher_icons: ^0.14.3  # 앱 아이콘 생성
```

---

## ✅ 주요 변경 이력

### 2026-03-30

- **지도 화면 개편** (`map_naver.dart`) — Naver Maps 기반 주 지도 화면으로 확정, `map.dart`(Google Maps)는 레퍼런스용 보관
- **장소 검색 개선** (`map_naver.dart`)
  - 실시간 debounce 검색 (300ms), 2글자 미만 미호출
  - 검색 결과 탭 시 해당 위치에 네이버 기본 마커 표시 (크기 26×36)
- **POI 심볼 탭 인터랙션** (`map_naver.dart`)
  - `consumeSymbolTapEvents: true` — 네이버 기본 말풍선 대신 커스텀 하단 카드로 대체
  - 탭 시 zoom 16으로 카메라 이동 + 기존 검색 API로 주소 조회
  - 하단 카드 slide-up: 장소명, 주소 표시
- **커스텀 마커 탭 인터랙션** (`map_naver.dart`)
  - `setOnTapListener`로 탭 감지
  - 하단 카드 slide-up: 제목, 닉네임, 주소, 좋아요 수, 댓글 수, 자세히 보기 버튼(`/detail-board`)
  - 마커 타이틀 10자 초과 시 `...` 처리
  - subCaption 임시 미사용 (추후 해시태그 정보로 변경 예정)
- **하단 카드 공통**
  - 핸들 바 드래그로 카드 닫기 (80px 이상 또는 빠른 스와이프 시 닫힘)
  - 맵 탭 시 카드 닫힘
  - POI 카드 ↔ 게시글 카드 동시에 하나만 표시
- **공유하기 버튼** (`map_naver.dart`) — 내 위치 버튼 위에 파란 `+` FAB, 탭 시 공유하기 탭(index 1)으로 이동
- **이 주변 스토리 조회 버튼** (`map_naver.dart`)
  - 지도 이동 또는 줌 3단계 이상 변경 후 카메라 정지 시 하단 버튼 표시
  - 초기 로드 시 미표시, 카드 열릴 시 숨김
  - 탭 시 현재 위치·줌을 기준값으로 업데이트 + API 호출 예정
- **줌 범위 제한** — minZoom: 10, maxZoom: 20
- **줌-반경 매핑 테이블** (백엔드용, zoom 10~20 → 22500m~22m, 서울 37.5°N 기준)
- **커스텀 마커 이미지** (`image_service.dart`) — 프로필 이미지 원형 크롭 + 흰색 테두리(8px) 적용

### 2026-03-23

- **게시판 파일 리팩토링** (`board2.dart` → `board.dart`)
  - `Board2Screens` → `BoardScreens`, `Board2Card` → `BoardCard` 클래스명 변경
  - `board2.dart`, `board2_card.dart` 삭제, FAB heroTag `board2_fab` → `board_fab`
  - `app_routes.dart` 임포트 및 사용처 일괄 업데이트

- **게시판 검색 정렬 UI 개선** (`board_search.dart`)
  - 드롭다운 → pill 칩 → 단일 버튼 + 바텀시트 방식으로 변경
  - 정렬 버튼 탭 시 아래에서 바텀시트 올라오며 옵션 선택
  - 현재 선택 항목 파란 배경 + 체크 아이콘 표시
  - 정렬 기능 연결: `최신순 → LATEST`, `좋아요순 → LIKES`, `댓글순 → REPLYS`

- **게시글 카드 더보기 버튼 변경** (`board_card.dart`)
  - 회색 배경 제거, `more_horiz` → `more_vert` (세로 점 3개), `#7AB3FF` 파란색 적용
  - 댓글 더보기 버튼 동일하게 통일 (`comment_item.dart`)

- **소셜 로그인 취소 버그 수정**
  - Google: `signIn()` 반환값 `null` 체크 → 취소 시 에러 알림 없이 조용히 종료
  - Kakao: catch 에서 `cancel` / `access_denied` 메시지 감지 → 조용히 종료
  - Naver: `onFailure` / `onError` 콜백에서 취소 메시지 감지 → 조용히 종료

- **로그인 화면 그라디언트 방향 수정** (`login.dart`)
  - `#A8CCFF → #7AB3FF → #3578E5` → `#3578E5 → #7AB3FF → #A8CCFF` (공유하기/프로필과 통일)

- **설정 화면** (`setting.dart`)
  - `알림설정` → `권한설정` 텍스트 변경
  - 아이콘 `notifications_outlined` → `security_outlined`

- **권한설정 화면 신규 추가** (`permission_setting.dart`)
  - 위치 / 카메라 / 사진 라이브러리 / 알림 4개 권한 상태 표시
  - 위치: `Geolocator.checkPermission()` — `whileInUse` / `always` 모두 허용 처리
  - 알림: `FirebaseMessaging.getNotificationSettings()` — 정확한 iOS 알림 권한 반영
  - 카메라 / 사진: `permission_handler` 사용
  - 허용(초록) / 거부됨(빨강) 뱃지 표시, 진입 시 자동 상태 조회
  - 탭 시 `app-settings:` URL 스킴으로 앱 전용 설정 페이지 바로 이동 (폴백: `openAppSettings()`)
  - 앱 복귀 시 권한 상태 자동 새로고침 (`WidgetsBindingObserver`)

- **이미지 디버그 로그 제거** (`board_card.dart`)
  - 이미지 로드 시작/완료/실패, 프로필 이미지 실패 로그 모두 삭제

### 2026-03-19
- **앱 이름 변경**: Unimal → 스토맵 (iOS `CFBundleDisplayName`, Android `android:label`)
- **로그인 화면 개편** (`login.dart`)
  - 로고: 파란 핀 + 빨간 말풍선 인라인 SVG
  - 배경: 그라디언트 `#A8CCFF → #7AB3FF → #3578E5`
  - 소셜 로그인 카드: white 95% 반투명 + `BorderRadius.circular(24)`
  - 진입 애니메이션: 로고 스케일+페이드 → 타이틀 슬라이드업 → 카드 슬라이드업 (순차, 1.2초)
  - 불필요한 login2~5.dart, 개별 버튼 위젯 파일 삭제
- **스플래시 화면** (`flutter_native_splash.yaml`)
  - 배경색: `#E8F2FF` (앱 아이콘 배경과 동일)
  - 중앙 이미지: 핀 이미지 240px
  - Android 12+: `app_icon_android.png` 사용 (원형 크롭 대응)
- **앱 아이콘** (`flutter_launcher_icons`)
  - iOS 1024px / Android 512px 적용
  - `remove_alpha_ios: true`
  - Adaptive icon 배경: `#E8F2FF`
- **공유하기 화면** (`add_item.dart`)
  - 배경: 그라디언트 `#3578E5 → #7AB3FF → #A8CCFF` (위가 진하게)
  - 카드: `BorderRadius.circular(24)`, white 95%
  - 업로드 버튼: white 카드 + `#7AB3FF` 텍스트
  - 진입 애니메이션: 헤더 → 이미지영역 → 제목/내용카드 → 위치/토글 → 버튼 스태거 (1초)
  - `TickerMode` 기반 탭 재진입 시 애니메이션 재생
- **하단 네비게이션** (`root_screen.dart`)
  - `BottomNavigationBar` 제거 → 커스텀 `_buildBottomNav()`
  - SVG 아이콘 `ColorFilter.mode()` 로 컬러 적용
  - 활성: `#5B9FEF`, 비활성: `#9E9E9E`
  - 상단 테두리 `#E8E8E8`, 소프트 그림자
- **프로필 화면** (`profile.dart`)
  - 배경: 그라디언트 `#3578E5 → #7AB3FF → #A8CCFF` (위가 진하게)
  - 스탯카드 추가: 내 스토리 (파란 핀 아이콘) + 받은 좋아요 (코랄 하트 아이콘)
  - "내 소식" → "내 스토리" 변경
  - 진입 애니메이션: 헤더 슬라이드다운 → 스탯카드 슬라이드업 → 콘텐츠 페이드 (데이터 로드 후 시작)
  - `TickerMode` 기반 탭 재진입 시 애니메이션 재생
- **내 개인정보 화면** (`mypage.dart`)
  - 저장하기 버튼: 그라디언트 `#3578E5 → #5B9FEF` + 그림자
  - 기존 `#4D91FF` → `#5B9FEF` 통일

---

## 🔒 보안

- **Secure Storage**: 민감한 사용자 정보 암호화 저장
- **환경 변수 분리**: `.env` 파일로 API 키 관리
- **토큰 관리**: JWT 기반 인증 토큰 자동 갱신
- **권한 관리**: 위치, 카메라 등 필요 권한만 요청

---

<p align="center">
  Made with ❤️ by kane
</p>
