# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**스토맵(Stomap)** Flutter 앱 — "지도 위에 스토리를 남기자". 백엔드는 `api.unimal.co.kr`(API Gateway, 포트 8080)를 단일 진입점으로 호출하는 Kotlin/Spring 마이크로서비스(별도 레포 `unimal-server`).

현재 **화이트 기반으로 디자인 전면 개편 중**. 모든 게시판을 지도 위로 가져오는 방향으로 리뉴얼 진행 중이며, 디자인은 Figma에서 확정 후 구현을 위임받는 워크플로우다.

## 🎨 디자인 토큰 규칙 (최우선 — 반드시 준수)

### 절대 규칙

1. **색상 하드코딩 금지.** `Color(0xFF...)`, `Colors.white`, `Colors.grey` 등 직접 사용 금지.
2. 모든 색상은 `lib/theme/app_colors.dart`의 시멘틱 토큰을 사용한다:
   ```dart
   final colors = AppColors.of(context);  // light/dark 자동 분기
   Container(color: colors.surface, ...)
   ```
3. 토큰에 없는 색이 필요하면 **임의 색을 쓰지 말고 `app_colors.dart`에 시멘틱 토큰을 추가**한 뒤 사용한다 (light/dark 둘 다 정의).
4. **보이스카웃 규칙**: 어떤 이유로든 수정하는 위젯/파일에 하드코딩 색상이 보이면 아래 매핑표에 따라 토큰으로 치환하고 나온다.
5. `Colors.transparent`만 예외적으로 허용.

### 레거시 색상 → 토큰 매핑표

기존 코드에 흩어져 있는 하드코딩 색상은 다음과 같이 치환한다:

| 레거시 값 | 토큰 |
|----------|------|
| `0xFF3578E5` | `primary` |
| `0xFF4D91FF` | `primaryStrong` |
| `0xFF7AB3FF`, `0xFFA8CCFF` | `primarySoft` |
| `0xFFEEF6FF`, `0xFFF0F7FF`, `0xFFF8FAFF` | `primaryWash` |
| `Colors.white`, `0xFFFFFFFF` | 화면 배경이면 `background`, 카드/시트면 `surface` |
| `0xFFF5F5F5`, `0xFFF1F5F9` | `surfaceVariant` |
| `0xFFF3F4F6` | `surfaceMuted` |
| `Colors.black`, `0xFF1A1A2E`, `0xFF2C3E50` | `textPrimary` |
| `0xFF374151`, `0xFF1F2937` | `textSecondary` |
| `0xFF6B7280`, `0xFF666666`, `Colors.grey` (진한 용도) | `textTertiary` |
| `0xFF9CA3AF`, `Colors.grey` (힌트/비활성) | `textMuted` |
| `0xFFE5E7EB`, `0xFFE2E8F0` | `border` |
| `0xFFCBD5E1`, `0xFFB8BFC8` | `borderStrong` |
| `0xFFDDDDDD` | `divider` |
| `0xFFE53935`, `0xFFEF4444`, `0xFFFF6B6B`, `Colors.red` | `danger` |
| `0xFFFF9F43` | `accent` |
| `0xFFFEE500` | `kakao` (카카오 로그인 전용, 변경 금지) |
| 그림자 계열 (`0x22000000` 등) | `shadow` |

판단이 애매한 색(예: 특정 상태 표시용 green)은 임의 매핑하지 말고 토큰 추가를 제안할 것.

### 톤 방향

- **화이트 기반, 깔끔하게.** 넓은 여백, 옅은 `border`/`divider`로 구분, 그림자는 최소한으로.
- 블루(`primary` 계열)는 배경이 아니라 **강조 액센트로만** 사용 (마커, 활성 상태, CTA).
- 새 화면은 다크모드를 항상 고려한다 — `AppColors.of(context)`를 쓰면 자동 대응됨.

## Commands

```bash
flutter pub get          # 의존성 설치
flutter run              # 실행 (디바이스/에뮬레이터)
flutter analyze          # 정적 분석 — 작업 완료 전 반드시 실행
flutter build apk        # Android 빌드
flutter build ipa        # iOS 빌드
```

## Architecture

```
lib/
├── screens/         # 화면 단위 UI
│   ├── map/         # 지도 (네이버 지도) — 앱의 중심 화면. bottom_card/ 포함
│   ├── board/       # 게시글 카드/상세/댓글 (지도 위 표시로 이전 중)
│   ├── add/         # 게시글 작성
│   ├── auth/        # 로그인/회원가입/인증
│   ├── profile/     # 마이페이지, 설정
│   ├── navigation/  # 루트 네비게이션
│   └── web/         # 웹뷰
├── service/         # API 호출 (auth, board, map, image, push, user 등)
├── state/           # 상태 관리
├── theme/           # app_colors.dart — 디자인 토큰 (시멘틱, light/dark)
└── utils/           # 공통 유틸
```

## 백엔드 연동

- 모든 API는 Gateway(`api.unimal.co.kr`) 경유. 로그인 성공 시 응답 헤더의 `X-Unimal-Access-Token`, `X-Unimal-Refresh-Token`, `X-Unimal-Email`, `X-Unimal-Provider`를 SecureStorage에 저장.
- 401 응답 시 `ApiClient`가 `GET /user/auth/token-reissue`로 자동 재발급.
- 지도 마커: `GET /board/map/location/post?latitude=&longitude=&zoom=` — score 기반 정렬, Flutter에서 `globalZIndex = 200000 + score`로 마커 우선순위 결정.

## 작업 시 주의

- 기존 화면 수정 시 동작 변경 없이 토큰 치환만 하는 경우에도 `flutter analyze` 통과 확인.
- 지도 화면(`screens/map/`)과 로그인은 이미 토큰 치환 완료 — 해당 화면의 패턴을 참고할 것.

## 📄 문서 작성 규칙 (docs/)

설계·계획·할일·트러블슈팅 문서는 **반드시 루트 `docs/` 아래에만** 만든다. `lib/` 등 코드 폴더 안에 `.md` 설계 문서를 만들지 않는다.

| 폴더 | 용도 | 명명 |
| --- | --- | --- |
| `docs/architecture/` | 앱 구조·상태관리·디자인 방침·방향성 (살아있는 문서) | 주제 기반 (`스토맵-방향성-구조-설계.md`) |
| `docs/specs/` | 기능별 설계 — 무엇을/왜 | `YYYY-MM-DD-주제.md` |
| `docs/plans/` | 구현 계획 — 어떻게/단계 | `YYYY-MM-DD-주제.md` |
| `docs/todo/` | 할일·백로그 | 주제 기반 |
| `docs/troubleshooting/` | 디버깅·장애 기록 | `YYYY-MM-DD-주제.md` |

- 어느 카테고리에도 안 맞는 표준/포맷 문서(`release-note-format.md` 등)는 `docs/` 루트에 둔다.
- 자동화 도구(superpowers 등)가 `docs/superpowers/...`에 문서를 생성하면, 작업 종료 전 위 카테고리 폴더로 옮기고 `superpowers/`는 비운다.
- 한글 파일명은 공백 대신 하이픈(`-`)을 쓴다.
- 자세한 규칙은 `docs/README.md` 참고.

## Git 커밋 규칙

- **중간 커밋 금지.** 작업(요청받은 과제) 단위로 나눠서 커밋하지 않는다.
- 요청받은 작업이 **전부 끝난 뒤 한 번에 커밋**한다 (`flutter analyze` 통과 확인 후).
- 사용자가 명시적으로 요청하기 전에는 커밋하지 않는다.
