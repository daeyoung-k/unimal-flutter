# 프로필 이미지 크롭 / Android 확장 카드 오류 처리 예정

작성일: 2026-06-17  
상태: 수정 예정  
범위: 프로필 이미지 표시, 지도 화면 확장 카드 Android 안전 영역

---

## 1. 프로필 사진 흰선 노출

### 증상

프로필 사진이 원형 영역에 꽉 차지 않아 위/아래/좌/우에 흰 선이 보인다.

### 영향

- 프로필 이미지가 정돈되지 않아 UI 완성도가 떨어져 보인다.
- 원형 아바타 내부 이미지가 배경/테두리와 분리되어 보일 수 있다.

### 확인한 관련 코드

- `lib/screens/profile/profile.dart`
  - 마이페이지 히어로 카드 프로필 이미지
  - `CachedNetworkImage(fit: BoxFit.cover)` 사용
- `lib/screens/board/card/board_card_profile.dart`
  - 게시글 카드 프로필 이미지
  - `CircleAvatar` 안에 `ClipOval + Image.network(width: 36, height: 36, fit: BoxFit.cover)` 사용
- `lib/screens/map/bottom_card/map_bottom_card.dart`
  - 지도 카드 프로필 이미지
  - `CachedNetworkImage(fit: BoxFit.cover)` 사용
- `lib/screens/map/bottom_card/map_card_expanded_content.dart`
  - 확장 카드/댓글 프로필 이미지

### 추정 원인

일부 프로필 이미지 위젯에서 원형 컨테이너, 테두리, 클립 영역, 이미지 실제 크기가 정확히 일치하지 않을 가능성이 있다.

특히 `CircleAvatar` 내부에 다시 `ClipOval`과 고정 크기 이미지를 넣는 구조는 Android 렌더링에서 미세한 경계가 보일 수 있다.

### 수정 방향

- 프로필 아바타를 공통 위젯으로 정리한다.
- 모든 프로필 이미지 표시에서 같은 구조를 사용한다.
- 원형 클립 영역과 이미지 크기를 동일하게 맞춘다.
- 이미지에는 `BoxFit.cover`를 유지한다.
- 테두리가 필요한 경우 이미지 바깥 컨테이너에서만 처리하고, 내부에는 흰 배경이 새어 나오지 않게 한다.

### 완료 기준

- iOS와 Android 모두에서 프로필 이미지가 원형 영역을 꽉 채운다.
- 위/아래/좌/우 흰 선이 보이지 않는다.
- 이미지가 없는 경우의 기본 아바타도 기존 스타일을 유지한다.

---

## 2. Android 확장 카드가 카메라 영역까지 올라가는 문제

### 증상

Android 폰에서 지도 화면 확장 카드가 상단 카메라/펀치홀 영역까지 올라간다.

닫으려고 상단 근처를 터치하면 카드가 아니라 카메라 영역이 터치되는 느낌이 난다.

iOS에서는 현재 문제가 크게 보이지 않는다.

### 영향

- Android에서 확장 카드 닫기 동작이 불편하다.
- 상단 안전 영역을 침범해 화면이 답답해 보인다.
- 사용자가 카드를 닫으려다 의도하지 않은 영역을 터치할 수 있다.

### 확인한 관련 코드

- `lib/screens/map/map_naver.dart`
  - `MapBottomCard`에 `minTopMargin` 전달
  - 현재 기본값: `MediaQuery.paddingOf(context).top + 80`
  - 검색바 측정값이 있으면 `_searchBarBottom + 30`
- `lib/screens/map/bottom_card/map_bottom_card.dart`
  - `_maxCardHeight(screenHeight) => screenHeight - widget.minTopMargin`
  - 확장 상태에서는 `_baseCardHeight()`에서 ratio `1.0` 사용
  - 즉 확장 카드 높이는 `screenHeight - minTopMargin`까지 올라갈 수 있음
- `lib/screens/map/bottom_card/map_bottom_card.dart`
  - 기본 카드 상태에서는 콘텐츠 영역 수직 드래그가 가능
  - 확장 상태에서는 내부 스크롤을 위해 콘텐츠 드래그가 비활성화되고, 핸들 영역 위주로 축소 처리

### 추정 원인

Android 기기에서 `MediaQuery.paddingOf(context).top`만으로는 카메라/펀치홀 주변 체감 안전 영역을 충분히 확보하지 못하는 케이스가 있다.

또 확장 상태에서는 카드 내부 콘텐츠 영역이 스크롤을 가져가므로, 이미지 영역에서 아래로 스와이프해 닫는 동작이 충분히 잡히지 않을 수 있다.

### 수정 방향

#### 1. Android 확장 카드 상단 여백 증가

Android에서만 확장 카드의 최대 높이를 조금 낮춘다.

예상 방향:

- iOS: 현재 기준 유지
- Android: `minTopMargin`에 추가 여백 적용
- 검색바 기준이 있는 경우에도 Android 추가 여백을 반영

예시 기준:

```dart
final platformExtraTopMargin = Platform.isAndroid ? 20.0 : 0.0;
```

실제 값은 기기 테스트 후 조정한다.

#### 2. 확장 카드 이미지 영역에서 아래 스와이프 시 축소/닫기 가능하게 처리

확장 카드에서 상단 핸들만 의존하지 않고, 이미지 영역에서도 수직 드래그를 받을 수 있게 한다.

예상 동작:

- 확장 상태에서 이미지 영역을 아래로 스와이프하면 기본 카드 상태로 축소
- 충분히 크게 아래로 스와이프하는 경우 닫기까지 허용할지 검토
- 내부 댓글/본문 스크롤 영역과 제스처 충돌이 없도록 이미지 영역에 한정해서 먼저 적용

### 완료 기준

- Android에서 확장 카드가 카메라/펀치홀 영역까지 올라가지 않는다.
- Android에서 확장 카드 상단을 닫으려 할 때 시스템/카메라 영역 터치 느낌이 나지 않는다.
- 확장 카드 이미지 영역에서 아래로 스와이프해 카드를 내릴 수 있다.
- iOS 기존 사용감은 유지된다.

---

## 테스트 기준

### 수동 확인

- iOS 실제 기기 또는 시뮬레이터
- Android 실제 기기 또는 에뮬레이터

### 확인 시나리오

1. 프로필 이미지가 있는 사용자로 로그인한다.
2. 마이페이지, 게시글 카드, 지도 카드, 확장 카드 댓글 영역의 프로필 이미지를 확인한다.
3. Android에서 지도 마커를 선택한다.
4. 카드를 확장한다.
5. 확장 카드 상단이 카메라/펀치홀 영역을 침범하지 않는지 확인한다.
6. 확장 카드 이미지 영역에서 아래로 스와이프해 카드가 내려가는지 확인한다.
7. 댓글 리스트/본문 스크롤과 제스처가 충돌하지 않는지 확인한다.
