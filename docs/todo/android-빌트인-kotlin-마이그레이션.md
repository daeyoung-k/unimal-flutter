# Android Built-in Kotlin 마이그레이션 (다음 세션)

`flutter build/run` 시 나오는 Kotlin/KGP 경고 해결. 완료 후 우리지도 개발 시작.

## 현재 상태

- `android/settings.gradle:25` — `org.jetbrains.kotlin.android` **2.1.20** (Flutter 지원 하한 2.2.20 미만 → 경고)
- `android/gradle.properties` — Flutter 마이그레이터가 자동 추가한 `android.builtInKotlin=false`, `android.newDsl=false` (커밋 8afd48f). 즉 아직 **구 방식(KGP 직접 적용)으로 옵트아웃**된 상태.
- KGP를 적용하는 플러그인들: device_info_plus, flutter_naver_map, kakao_flutter_sdk_common, naver_login_sdk, package_info_plus, shared_preferences_android, webview_flutter_android

## 할 일 (순서대로)

1. **KGP 버전 범프 (급한 것, 저위험)**
   - `settings.gradle`의 `org.jetbrains.kotlin.android`를 2.2.20+로 올리고 Android 빌드 확인.
   - 이것만으로 "Kotlin version will soon be dropped" 경고는 해소.
2. **앱 Built-in Kotlin 전환**
   - 가이드: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers
   - `settings.gradle`/`app/build.gradle`에서 kotlin.android 플러그인 제거, `android.builtInKotlin=true`(+`newDsl=true`) 전환.
3. **플러그인 KGP 경고**
   - 위 7개 플러그인 최신 버전이 Built-in Kotlin을 지원하는지 changelog 확인 후 업그레이드.
   - 미지원 플러그인(특히 naver_login_sdk, kakao_flutter_sdk_common 같은 서드파티)은 당장 빌드 실패가 아니므로 **경고 상태로 두고 추후 재확인**. 필요시 플러그인 레포에 이슈.

## 주의

- 2번/3번은 Android 빌드 체인 변경이라 `flutter build apk` + 실기기 확인까지 하고 커밋.
- 한 번에 다 하지 말고 1 → 2 → 3 단계별로 빌드 검증.

## 이후

- 우리지도 개발 시작 — 설계는 `docs/specs/2026-07-11-비밀지도-UX.md` 및 우리지도 리스트/탐색 UX 설계(커밋 1e44224) 참고.
