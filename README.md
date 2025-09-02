# 🐾 Unimal - 우리 주변 동물

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/GetX-8B1538?style=for-the-badge&logo=getx&logoColor=white" alt="GetX">
</p>

## 📱 프로젝트 소개

**Unimal** 사용자들이 위치 기반으로 야생동물과 반려동물의 사진과 정보를 지도에 공유할 수 있는 커뮤니티 기반 플랫폼입니다.

### 🎯 주요 특징

- **📍 위치 기반 서비스**: Google Maps를 활용한 사용자 주변 정보 제공
- **💬 커뮤니티 게시판**: 사용자들 간 정보 공유 및 소통 공간
- **🔐 소셜 로그인**: 카카오, 네이버, 구글 간편 로그인 지원
- **🎨 모던한 UI/UX**: Material Design 3 기반의 직관적인 인터페이스

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
```

## 📂 프로젝트 구조

```
lib/
├── main.dart                    # 앱 진입점
├── models/                      # 데이터 모델
│   ├── board_post.dart
│   └── signup_models.dart
├── screens/                     # UI 화면
│   ├── auth/                   # 인증 관련
│   │   ├── login/
│   │   ├── signup.dart
│   │   └── tel_verification.dart
│   ├── board/                  # 게시판
│   │   ├── board.dart
│   │   └── widget/
│   ├── navigation/             # 네비게이션
│   │   ├── root_screen.dart
│   │   └── app_routes.dart
│   ├── home.dart
│   ├── search.dart
│   └── profile.dart
├── service/                    # 비즈니스 로직
│   ├── auth/
│   ├── login/
│   └── user/
├── state/                      # 상태 관리
│   ├── auth_state.dart
│   └── secure_storage.dart
└── repositories/               # 데이터 레이어
    └── board_repository.dart
```

## 🎨 UI/UX 특징

### 디자인 시스템
- **컬러 테마**: 블루(#4D91FF) 메인 컬러의 모던한 디자인
- **타이포그래피**: Pretendard, InstagramSans 폰트 조합
- **컴포넌트**: Material Design 3 기반 커스텀 컴포넌트

### 주요 화면
1. **로그인/회원가입**: 소셜 로그인 및 전화번호 인증
2. **홈 피드**: 실시간 게시물 및 활동 표시
3. **게시판**: 무한 스크롤, 이미지 슬라이드, 좋아요/댓글 기능
4. **지도**: 사용자 주변 정보 마커 표시
5. **프로필**: 사용자 정보 및 활동 내역

## 🔒 보안 기능

- **Secure Storage**: 민감한 사용자 정보 암호화 저장
- **환경 변수 분리**: 개발/프로덕션 환경 구분
- **토큰 관리**: JWT 기반 인증 토큰 자동 갱신
- **권한 관리**: 위치, 카메라 등 필요 권한만 요청

## 📈 주요 기능

### 인증 시스템
- 카카오, 네이버, 구글 소셜 로그인
- 이메일/비밀번호 로그인
- 전화번호 인증
- 자동 로그인 및 세션 관리

### 게시판 기능
- 실시간 피드 업데이트
- 이미지 업로드 (최대 10장)
- 좋아요 및 댓글
- 무한 스크롤 페이지네이션
- 검색 및 필터링

### 위치 서비스
- Google Maps 통합
- 커스텀 마커 표시
- 현재 위치 추적
- 주변 정보 검색

---

<p align="center">
  Made with ❤️ by kane
</p>
