# 스토맵 (Stomap)

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/GetX-8B1538?style=for-the-badge&logo=getx&logoColor=white" alt="GetX">
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase">
</p>

## 📱 프로젝트 소개

**스토맵(Stomap)** 은 지도 위에 나만의 이야기를 핀으로 남기고, 주변 사람들과 공유하는 위치 기반 스토리 공유 앱입니다.

> "지도 위에 당신의 이야기를 남기세요"

### 🎯 주요 기능

- **📍 위치 기반 스토리**: 현재 위치에 스토리를 핀으로 등록하고 지도에 노출
- **💬 커뮤니티 게시판**: 스토리 피드, 좋아요, 댓글/대댓글
- **🔐 소셜 로그인**: 카카오, 네이버, 구글 간편 로그인 지원
- **🔔 앱 푸시 알림**: 좋아요/댓글/공지사항/이벤트 알림 및 화면 이동
- **🗺 네이버 지도**: 마커 그룹핑, score 기반 우선순위, 장소 검색
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
- **화면 배경** (로그인/공유하기/프로필): `#3578E5` → `#7AB3FF` → `#A8CCFF` (위→아래)
- **버튼**: `#3578E5` → `#5B9FEF` (위→아래)

### 타이포그래피
- **기본 폰트**: Pretendard
- **앱 이름**: `w800`, 32px, white

### 공통 컴포넌트
- 카드: `BorderRadius.circular(24)`, `Colors.white.withOpacity(0.95)`, 부드러운 그림자
- 버튼: `BorderRadius.circular(14)`, 그라디언트 적용
- 로그인 버튼: `BorderRadius.circular(14)`, height 54

---

## 📂 전체 화면 구조

```
lib/screens/
├── auth/
│   ├── login/
│   │   ├── login.dart                   # 소셜(카카오·네이버·구글) + 이메일 로그인
│   │   └── widget/manual_login_form.dart
│   ├── signup.dart                      # 회원가입
│   ├── tel_verification.dart            # 전화번호 인증
│   ├── id_find.dart                     # 아이디 찾기
│   └── password_find.dart               # 비밀번호 찾기
│
├── map/
│   ├── map_naver.dart                   # 네이버 지도 (주 화면)
│   ├── map.dart                         # Google Maps (레퍼런스용 보관)
│   └── marker/marker_preview.dart       # 마커 이미지 미리보기
│
├── add/
│   └── add_item.dart                    # 스토리 공유하기 (위치·사진·텍스트)
│
├── board/
│   ├── board.dart                       # 게시판 피드 (검색·정렬)
│   ├── card/board_card.dart             # 게시물 카드
│   ├── card/board_card_content.dart
│   ├── card/board_card_image.dart
│   ├── card/board_card_profile.dart
│   ├── card/board_search.dart           # 검색 + 바텀시트 정렬
│   ├── widget/indicator.dart
│   ├── widget/photo_arrow.dart
│   ├── detail_board/detail_board.dart   # 게시물 상세
│   ├── detail_board/detail_card/...     # 상세 화면 서브 컴포넌트
│   ├── detail_board/comment/...         # 댓글 섹션·입력·아이템
│   └── edit_board/edit_board.dart       # 게시물 수정
│
├── profile/
│   ├── profile.dart                     # 프로필 (스탯카드 + 내 스토리)
│   ├── mypage/mypage.dart               # 개인정보 수정
│   └── setting/
│       ├── setting.dart                 # 설정 메인
│       ├── permission_setting.dart      # 권한설정 (위치·카메라·사진·알림)
│       ├── privacy_policy.dart          # 개인정보 처리방침
│       ├── terms_of_service.dart        # 이용약관
│       └── notice/
│           ├── notice_list.dart         # 공지사항 목록
│           └── notice_detail.dart       # 공지사항 상세
│
├── web/
│   └── web_view_screen.dart             # 인앱 웹뷰 (이벤트·외부링크)
│
└── navigation/
    ├── root_screen.dart                 # 하단 네비게이션 (4탭)
    ├── app_routes.dart                  # 전체 라우트 정의
    └── deep_link.dart                   # 딥링크 처리
```

---

## 🗺 라우트 구조

| 라우트 | 화면 | 비고 |
|--------|------|------|
| `/map` | 지도 (index 0) | 기본 진입 화면 |
| `/add` | 공유하기 (index 1) | |
| `/board` | 게시판 (index 2) | |
| `/mypage` | 프로필 (index 3) | |
| `/login` | 로그인 | |
| `/signup` | 회원가입 | |
| `/tel-verification` | 전화번호 인증 | |
| `/id-find` | 아이디 찾기 | |
| `/password-find` | 비밀번호 찾기 | |
| `/detail-board` | 게시물 상세 | `?id=boardId` |
| `/edit-board` | 게시물 수정 | arguments: BoardPost |
| `/notice-list` | 공지사항 목록 | |
| `/webview` | 인앱 웹뷰 | `?url=...&title=...` |

---

## 🛠 기술 스택

### Frontend
- **Framework**: Flutter (SDK ^3.8.0)
- **Language**: Dart
- **상태관리**: GetX 4.7.2
- **네비게이션**: GetX Router

### 주요 패키지
```yaml
# 지도 & 위치
flutter_naver_map: ^1.4.4         # 네이버 지도 (주 사용)
google_maps_flutter: ^2.12.3      # Google Maps (보관용)
geolocator: ^11.0.0               # GPS 위치

# 소셜 로그인
kakao_flutter_sdk: ^1.9.6
naver_login_sdk: ^2.3.0
google_sign_in: ^6.3.0

# 푸시 알림
firebase_core: ^4.3.0
firebase_messaging: ^16.1.0
flutter_local_notifications: ^19.5.0

# 데이터 & 보안
http: ^1.3.0
flutter_secure_storage: ^9.2.4
flutter_dotenv: ^5.2.1

# UI/UX
flutter_native_splash: ^2.4.4
flutter_svg: ^2.0.17
cached_network_image: ^3.4.1
webview_flutter: ^4.13.1

# 유틸리티
image_picker: ^1.0.7
permission_handler: ^11.3.0
package_info_plus: ^9.0.0
device_info_plus: ^10.1.0
url_launcher: ^6.3.2
app_links: ^6.4.1
logger: ^2.5.0
```

---

## 🏗 아키텍처

```
UI Layer (screens/)
    ↕ GetX 상태관리
Service Layer (service/)
    ↕
Utils Layer (utils/api_client.dart)   ← 자동 토큰 재발급
    ↕
Backend API (api.unimal.co.kr)
```

### 상태관리 (lib/state/)
| 파일 | 역할 |
|------|------|
| `auth_state.dart` | 로그인 상태, 토큰, FCM 토큰 |
| `nav_controller.dart` | 하단 탭 선택 상태 |
| `secure_storage.dart` | FlutterSecureStorage 래퍼 |
| `state_init.dart` | 앱 시작 시 상태 복원 |

### 유틸리티 (lib/utils/)
| 파일 | 역할 |
|------|------|
| `api_client.dart` | HTTP 클라이언트 (401 시 토큰 자동 재발급) |
| `api_uri.dart` | 환경별 URL 생성 (local/prod) |
| `custom_alert.dart` | 공통 알럿·스낵바 |
| `time_utils.dart` | 상대 시간 변환 (방금 전, N분 전 등) |
| `mime_type_utils.dart` | 이미지 MIME 타입 관리 |

---

## 🔔 앱 푸시 알림

### FCM data 페이로드 구조
```json
{
  "type": "LIKE | REPLY | NOTICE | EVENT",
  "target_id": "대상 ID",
  "url": "이벤트 URL (EVENT 타입만)",
  "title": "웹뷰 제목 (EVENT 타입만)"
}
```

### 타입별 화면 이동
| type | 이동 화면 |
|------|----------|
| `LIKE` | 게시글 상세 (`/detail-board?id=target_id`) |
| `REPLY` | 게시글 상세 (`/detail-board?id=target_id`) |
| `NOTICE` | 공지사항 목록 (`/notice-list`) |
| `EVENT` | 인앱 웹뷰 (`/webview?url=...`) |

### 처리 상태
- **포그라운드**: FCM 수신 → 로컬 알림 표시 → 클릭 시 라우팅
- **백그라운드**: 시스템 알림 표시 → 클릭 시 `onMessageOpenedApp` → 라우팅
- **종료 상태**: 앱 실행 → `getInitialMessage` → 라우팅

---

## 🗺 지도 기능 상세

### 마커 시스템
- `GET /board/map/location/post?latitude=&longitude=&zoom=` 로 마커 데이터 조회
- `score` 값 기반 `globalZIndex` 자동 적용 (`200000 + score.toInt()`) → 높은 score가 위에 표시
- 소수점 3자리 기준 (~111m 반경) 동일 좌표 마커 그룹핑
- 같은 위치 복수 게시글 → 하단 카드 `PageView` 가로 스와이프

### 인터랙션
- **커스텀 마커 탭**: 하단 카드 slide-up (제목·주소·내용 미리보기·좋아요·댓글·자세히 보기)
- **POI 심볼 탭**: 네이버 기본 말풍선 대신 커스텀 하단 카드 (장소명·주소)
- **이 주변 스토리 조회**: 지도 이동/줌 변경 후 버튼 표시 → 탭 시 API 재조회
- **장소 검색**: debounce 300ms, 결과 탭 시 마커 + 카메라 이동
- **카드 드래그**: 핸들바 80px 이상 또는 빠른 스와이프로 닫기

---

## 🔒 보안

- **Secure Storage**: 액세스 토큰, 리프레시 토큰, FCM 토큰 암호화 저장
- **자동 토큰 갱신**: `ApiClient`에서 401 응답 시 리프레시 토큰으로 자동 재발급
- **환경 변수 분리**: `.env.local` / `.env.prod` 로 API 키 관리
- **권한 관리**: 위치·카메라·사진·알림 권한 통합 관리 (`PermissionService`)

### 환경 변수 키 목록
```
API_SCHEME, ANDORID_SERVER, IOS_SERVER
NAVER_MAP_CLIENT_ID
NAVER_LOGIN_CLIENT_ID, NAVER_LOGIN_CLIENT_SECRET, NAVER_LOGIN_CLIENT_NAME
NAVER_LOGIN_IOS_URL_SCHEME
NAVER_GEOCODING_CLIENT_ID, NAVER_GEOCODING_CLIENT_SECRET
KAKAO_APP_KEY
MAP_STYLE_IOS_ID, MAP_STYLE_ANDROID_ID
```

---

## 📱 앱 정보

| 항목 | 값 |
|------|-----|
| 앱 이름 | 스토맵 |
| 버전 | 1.0.0+1 |
| Android 패키지 | com.unimal.android |
| iOS Bundle ID | com.unimal.ios |
| 최소 SDK | Android: 정의 파일 참고 / iOS: 정의 파일 참고 |
| Firebase 프로젝트 | unimal-project |

### Android 권한
```
INTERNET, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION,
ACCESS_BACKGROUND_LOCATION, CAMERA, READ_MEDIA_IMAGES, POST_NOTIFICATIONS
```

### iOS 권한
```
NSLocationWhenInUseUsageDescription   # 위치 (사용 중)
NSLocationAlwaysUsageDescription      # 위치 (항상)
NSCameraUsageDescription              # 카메라
NSPhotoLibraryUsageDescription        # 사진첩
UIBackgroundModes: remote-notification # 백그라운드 푸시
```

---

## ⚠️ 출시 전 체크리스트

- [ ] `update_check_service.dart` 앱스토어 ID 실제 값으로 교체 (`id1234567890`)
- [ ] `main.dart` 업데이트 체크 활성화 (`checkAndHandleUpdate()` 주석 해제)
- [ ] `.env.prod` 서버 주소 및 API 키 최종 확인
- [ ] Firebase 프로젝트 푸시 알림 인증서 등록 확인 (iOS APNs)

---

## ✅ 주요 변경 이력

### 2026-04-07

- **앱 푸시 라우팅 구현** (`push_notification_service.dart`)
  - 알림 클릭 시 `type` 필드 기반 화면 이동 (LIKE/REPLY/NOTICE/EVENT)
  - 포그라운드·백그라운드·종료 상태 3가지 경로 모두 처리
  - payload `jsonEncode` 적용으로 포그라운드 알림 데이터 파싱 가능

- **웹뷰 화면 추가** (`screens/web/web_view_screen.dart`)
  - `url`, `title` 파라미터로 동작 (`/webview` 라우트)
  - 이전 화면 없을 시 지도 화면으로 이동

- **지도 마커 API 연동** (`map_naver.dart`)
  - `GET /board/map/location/post` 연동
  - `score` 기반 `globalZIndex` 자동 적용
  - 소수점 3자리 기준 마커 그룹핑 + PageView 카드

- **이미지 로드 실패 처리** — 실패 시 마커 표시 생략

- **공유하기 버그 수정** — `postalCode` 조건 제거, 위치 타임아웃 3초, 위치 오류 시 권한설정 이동

### 2026-03-30

- **지도 화면 개편** — Naver Maps 기반으로 확정, POI/커스텀 마커 인터랙션, 이 주변 스토리 조회 버튼
- **공지사항 API 연동**
- **권한설정 화면 권한 요청 로직 추가**

### 2026-03-23

- **게시판 리팩토링** (`board2.dart` → `board.dart`)
- **게시판 검색 정렬 UI** — 바텀시트 방식으로 변경
- **소셜 로그인 취소 버그 수정** (카카오·네이버·구글)
- **권한설정 화면 신규 추가** (`permission_setting.dart`)

### 2026-03-19

- **앱 이름 변경**: Unimal → 스토맵
- **로그인 화면 전면 개편** — 그라디언트 배경, 애니메이션
- **스플래시 화면 / 앱 아이콘** 적용
- **공유하기·프로필·하단 네비게이션** UI 전면 개편

---

<p align="center">
  Made with ❤️ by kane
</p>
