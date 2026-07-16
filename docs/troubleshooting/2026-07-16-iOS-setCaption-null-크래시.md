# iOS setCaption(null) 즉시 크래시 (2026-07-16)

## 증상

스택 펼침 접기(수렴 애니메이션) 시작 직후 iOS 앱 강제 종료.

```
flutter_naver_map/MarkerHandler.swift:66: Fatal error:
Unexpectedly found nil while unwrapping an Optional value
```

로그 상 `collapseStackFan (animate=true)` 직후 발생.

## 원인

`NMarker.setCaption(NOverlayCaption? value)` — **Dart 시그니처는 nullable**
이지만, iOS 네이티브 핸들러(`MarkerHandler.swift:66`)가 method channel 로
넘어온 caption 인자를 **강제 언래핑**한다. null 을 보내면 그대로 크래시.

접기 애니메이션 시작 시 죽어가는 팬 마커의 캡션을 지우려고
`m.setCaption(null)` 을 호출한 것이 트리거.

Android 는 무증상일 수 있으나 iOS 는 100% 재현 — 플러그인
flutter_naver_map 1.4.4 의 Dart/네이티브 시그니처 불일치 버그.

## 해결

캡션 제거는 null 대신 **빈 캡션**으로:

```dart
m.setCaption(const NOverlayCaption(text: ''));
```

내지도(my_story_map_screen)의 클러스터 버블에서 이미 검증된 패턴.

## 교훈

- flutter_naver_map 의 nullable Dart API 를 믿지 말 것 — 네이티브가
  같은 계약을 지키는지 별개 문제 (iOS 크래시 3건 모두 이 계열:
  NOverlayImage 경로 nil, ClusteringController race, setCaption null).
- 오버레이 속성 "제거"는 null 대신 빈 값/기본값 설정으로 우회.
