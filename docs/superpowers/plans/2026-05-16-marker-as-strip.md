# Marker-as-Strip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 썸네일 스트립을 제거하고, 선택된 마커에 파란 링 + 핀 꼬리를 합성하여 지도 마커가 스트립 역할을 대신하게 한다.

**Architecture:** `ImageService.addSelectionRing()` 이 기존 마커 bytes(200×200)를 200×240 PNG로 재합성(파란 링 + 핀 꼬리). `map_naver.dart` 의 `_applySelectionHighlight()` 가 핀 아이콘 대신 이 합성 이미지를 비동기 캐시로 적용. `map_bottom_card.dart` 는 `MapThumbnailStrip` 과 관련 코드를 제거한다.

**Tech Stack:** Flutter, `dart:ui` Canvas API, `flutter_naver_map` (`NClusterableMarker`, `NOverlayImage`), `flutter_test`

---

## 파일 목록

| 파일 | 변경 유형 |
|------|---------|
| `lib/service/image/image_service.dart` | `addSelectionRing` 추가, `createPinMarkerImage` 삭제 |
| `lib/screens/map/map_naver.dart` | 선택 하이라이트 링으로 교체, `onGroupChanged` 카메라 이동 추가, 핀 관련 코드 삭제 |
| `lib/screens/map/bottom_card/map_bottom_card.dart` | `MapThumbnailStrip` 및 관련 코드 삭제 |
| `test/service/image/image_service_test.dart` | 신규: `addSelectionRing` 단위 테스트 |
| `test/screens/map/bottom_card/map_thumbnail_strip_test.dart` | 삭제 |

---

### Task 1: `addSelectionRing()` 추가 + `createPinMarkerImage()` 삭제

**Files:**
- Modify: `lib/service/image/image_service.dart`
- Create: `test/service/image/image_service_test.dart`

- [ ] **Step 1: 테스트 디렉토리 생성 후 실패하는 테스트 작성**

```bash
mkdir -p test/service/image
```

`test/service/image/image_service_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:unimal/service/image/image_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('addSelectionRing', () {
    test('200×200 base bytes → 200×240 PNG 반환', () async {
      // 200×200 단색 PNG 생성 (실제 마커 bytes 대신 단순 더미)
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawCircle(const Offset(100, 100), 100, Paint()..color = const Color(0xFFFF0000));
      final img = await recorder.endRecording().toImage(200, 200);
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      final baseBytes = bd!.buffer.asUint8List();

      final result = await ImageService().addSelectionRing(baseBytes);

      // PNG 시그니처 확인
      expect(result.length, greaterThan(8));
      expect(result.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);

      // 디코딩해서 크기 확인
      final codec = await ui.instantiateImageCodec(result);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 200);
      expect(frame.image.height, 240);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 — FAIL 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && \
  flutter test test/service/image/image_service_test.dart
```
Expected: `Error: Method not found: 'addSelectionRing'`

- [ ] **Step 3: `addSelectionRing()` 구현 + `createPinMarkerImage()` 삭제**

`lib/service/image/image_service.dart` 에서 `createPinMarkerImage()` 메서드 전체를 삭제하고 아래 메서드로 교체한다.

```dart
/// 기존 마커 bytes(200×200)에 파란 테두리 링 + 핀 꼬리를 합성해 200×240 PNG 반환.
/// 선택된 마커 강조에 사용.
Future<Uint8List> addSelectionRing(Uint8List baseBytes) async {
  const double w = 200.0;
  const double h = 240.0;
  const double circleY = 100.0; // 원 중앙 Y (상단 200px 중앙)
  const Offset center = Offset(w / 2, circleY);
  const double outerRadius = 100.0; // 파란 링 외곽
  const double midRadius = 90.0;   // 흰 간격
  const double imgRadius = 86.0;   // 이미지 클립

  final codec = await ui.instantiateImageCodec(baseBytes);
  final frame = await codec.getNextFrame();
  final base = frame.image;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // 1. 파란 링
  canvas.drawCircle(center, outerRadius,
      Paint()..color = const Color(0xFF5B9FEF));

  // 2. 흰 간격 (링과 이미지 사이 분리선)
  canvas.drawCircle(center, midRadius,
      Paint()..color = Colors.white);

  // 3. 이미지 클립 후 그리기
  final clipPath = Path()
    ..addOval(Rect.fromCircle(center: center, radius: imgRadius));
  canvas.save();
  canvas.clipPath(clipPath);
  canvas.drawImageRect(
    base,
    Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()),
    Rect.fromCircle(center: center, radius: imgRadius),
    Paint(),
  );
  canvas.restore();

  // 4. 핀 꼬리 삼각형 — 원 하단 중앙(w/2, 200)에서 (w/2, 236)으로 뾰족하게
  final tailPath = Path()
    ..moveTo(w / 2 - 10, 200) // 왼쪽 기저
    ..lineTo(w / 2 + 10, 200) // 오른쪽 기저
    ..lineTo(w / 2, 236)      // 꼬리 끝
    ..close();
  canvas.drawPath(tailPath, Paint()..color = const Color(0xFF5B9FEF));

  // 5. 드롭섀도
  final shadowPath = Path()
    ..addOval(Rect.fromCircle(center: center, radius: outerRadius))
    ..addPath(tailPath, Offset.zero);
  canvas.drawShadow(shadowPath, Colors.black.withValues(alpha: 0.25), 4, false);

  final img = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}
```

- [ ] **Step 4: 테스트 실행 — PASS 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && \
  flutter test test/service/image/image_service_test.dart
```
Expected: `All tests passed!`

- [ ] **Step 5: analyze 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze
```
Expected: `No issues found!`

---

### Task 2: `map_naver.dart` — 핀 제거, 링 선택 하이라이트 적용

**Files:**
- Modify: `lib/screens/map/map_naver.dart`

변경할 위치는 grep 결과의 라인 번호 기준 다음 5개다.

#### 2-A: 필드 선언부 변경 (라인 49–52)

- [ ] **Step 1: `_pinIcon`, `_selectedMarkerWidth`, `_selectedMarkerHeight` 제거 → `_selectedIconCache` 추가**

삭제:
```dart
  NOverlayImage? _pinIcon;
  static const _selectedMarkerWidth = 36.0;
  static const _selectedMarkerHeight = 46.0;
```

추가 (같은 자리 또는 `_markerBaseZIndex` 선언 다음):
```dart
  final Map<String, NOverlayImage> _selectedIconCache = {};
```

#### 2-B: `_reloadMarkersForBrightnessChange()` 수정 (라인 118 부근)

- [ ] **Step 2: `_pinIcon = null` 제거 → `_selectedIconCache.clear()` 추가**

기존 메서드에 `_pinIcon = null` 라인은 없지만, `_highlightedMarkerId = null;` 바로 다음에 캐시 초기화를 추가한다.

현재 (라인 134):
```dart
    _highlightedMarkerId = null;

    // 마지막 조회 위치 기준으로 재로드.
```

변경 후:
```dart
    _highlightedMarkerId = null;
    _selectedIconCache.clear();

    // 마지막 조회 위치 기준으로 재로드.
```

#### 2-C: `_applySelectionHighlight()` + `_buildSelectedIconAsync()` (라인 569 부근)

- [ ] **Step 3: `_applySelectionHighlight()` 를 링 적용 방식으로 교체**

기존 메서드 전체를 아래로 교체:
```dart
  void _applySelectionHighlight(String? markerId) {
    final prevId = _highlightedMarkerId;
    if (prevId != null && prevId != markerId) {
      final prevMarker = _markerRefs[prevId];
      if (prevMarker != null) {
        final baseZ = _markerBaseZIndex[prevId];
        if (baseZ != null) prevMarker.setGlobalZIndex(baseZ);
        final originalIcon = _markerIconCache[prevId];
        if (originalIcon != null) prevMarker.setIcon(originalIcon);
        prevMarker.setSize(const Size(_normalMarkerSize, _normalMarkerSize));
      }
    }
    _highlightedMarkerId = markerId;
    if (markerId != null) {
      final marker = _markerRefs[markerId];
      if (marker != null) {
        marker.setGlobalZIndex(_selectedMarkerZIndex);
        final cached = _selectedIconCache[markerId];
        if (cached != null) {
          marker.setIcon(cached);
        } else {
          _buildSelectedIconAsync(markerId, marker);
        }
        // 크기는 일반 마커와 동일하게 유지 (링이 시각적 강조를 담당)
        marker.setSize(const Size(_normalMarkerSize, _normalMarkerSize));
      }
    }
  }

  Future<void> _buildSelectedIconAsync(
      String markerId, NClusterableMarker marker) async {
    final baseBytes = _markerBytesCache[markerId];
    if (baseBytes == null) return;
    try {
      final ringBytes = await _imageService.addSelectionRing(baseBytes);
      if (!mounted) return;
      final icon = await NOverlayImage.fromByteArray(ringBytes);
      _selectedIconCache[markerId] = icon;
      // 비동기 완료 시점에도 여전히 이 마커가 선택 중인지 확인
      if (_highlightedMarkerId == markerId) {
        marker.setIcon(icon);
      }
    } catch (_) {
      // 합성 실패 시 z-index 부스트만 유지 (방어)
    }
  }
```

#### 2-D: `_preparePinIcon()` 삭제 + `onMapReady` 호출 제거 (라인 744, 809)

- [ ] **Step 4: `_preparePinIcon()` 메서드 삭제**

아래 블록 전체 삭제:
```dart
  /// 선택 마커가 핀으로 즉시 교체될 수 있도록 onMapReady 시점에 핀 이미지를 1회 생성.
  Future<void> _preparePinIcon() async {
    try {
      final bytes = await _imageService.createPinMarkerImage();
      if (!mounted) return;
      _pinIcon = await NOverlayImage.fromByteArray(bytes);
    } catch (_) {
      // 핀 이미지 생성 실패 시: 선택 시 z-index 부스트만 적용 (방어)
    }
  }
```

- [ ] **Step 5: `onMapReady` 에서 `_preparePinIcon()` 호출 삭제**

현재 (라인 809):
```dart
            onMapReady: (controller) {
              setState(() => _mapController = controller);
              _preparePinIcon();
              _moveToCurrentLocationOrDefault();
            },
```

변경 후:
```dart
            onMapReady: (controller) {
              setState(() => _mapController = controller);
              _moveToCurrentLocationOrDefault();
            },
```

#### 2-E: `onGroupChanged` 에 카메라 이동 추가 (라인 1020 부근)

- [ ] **Step 6: `onGroupChanged` 콜백에 `_applySelectionHighlight` + `_moveCameraToMarker` 추가**

현재:
```dart
                      onGroupChanged: (newIdx) {
                        setState(() => _selectedGroupIndex = newIdx);
                        if (newIdx >= 0 && newIdx < _postGroups.length) {
                          _applySelectionHighlight(
                              _postGroups[newIdx].first.id);
                        }
                      },
```

변경 후:
```dart
                      onGroupChanged: (newIdx) {
                        setState(() => _selectedGroupIndex = newIdx);
                        if (newIdx >= 0 && newIdx < _postGroups.length) {
                          final post = _postGroups[newIdx].first;
                          _applySelectionHighlight(post.id);
                          final markerPos = _markerRefs[post.id]?.position
                              ?? NLatLng(post.latitude, post.longitude);
                          _moveCameraToMarker(markerPos);
                        }
                      },
```

- [ ] **Step 7: analyze 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze
```
Expected: `No issues found!`

---

### Task 3: `map_bottom_card.dart` — 스트립 제거

**Files:**
- Modify: `lib/screens/map/bottom_card/map_bottom_card.dart`

- [ ] **Step 1: import + 상수 제거**

아래 줄 삭제:
```dart
import 'package:unimal/screens/map/bottom_card/map_thumbnail_strip.dart';
```

아래 상수 삭제:
```dart
  static const _stripHeight = 82.0;
  static const _stripCardGap = 8.0;
```

- [ ] **Step 2: `_maxCardHeight()` 단순화**

현재:
```dart
  double _maxCardHeight(double screenHeight) =>
      screenHeight - widget.minTopMargin - _stripHeight - _stripCardGap;
```

변경 후:
```dart
  double _maxCardHeight(double screenHeight) =>
      screenHeight - widget.minTopMargin;
```

- [ ] **Step 3: `build()` 에서 스트립 + gap 제거**

현재 `build()` 의 Column children:
```dart
      children: [
        // 썸네일 스트립
        MapThumbnailStrip(
          groups: widget.groups,
          currentGroupIndex: _nav.groupIndex,
          onTap: _jumpToGroup,
          onVisualIndexChange: _previewGroup,
        ),
        const SizedBox(height: _stripCardGap),
        // 카드 본문
        AnimatedContainer(
```

변경 후:
```dart
      children: [
        // 카드 본문
        AnimatedContainer(
```

- [ ] **Step 4: `_navigateGroup()` 에서 `onCameraMove` 호출 제거**

현재:
```dart
  void _navigateGroup(int direction) {
    final result = direction > 0 ? _nav.nextGroup() : _nav.prevGroup();
    if (result == true) {
      widget.onCameraMove(
        NLatLng(_nav.currentPost.latitude, _nav.currentPost.longitude),
      );
      widget.onGroupChanged?.call(_nav.groupIndex);
      setState(() => _loadedDetail = null);
    } else if (result == null) {
      HapticFeedback.lightImpact();
    }
  }
```

변경 후 (`onCameraMove` 호출 제거 — 카메라 이동은 `onGroupChanged` 에서 map_naver.dart가 처리):
```dart
  void _navigateGroup(int direction) {
    final result = direction > 0 ? _nav.nextGroup() : _nav.prevGroup();
    if (result == true) {
      widget.onGroupChanged?.call(_nav.groupIndex);
      setState(() => _loadedDetail = null);
    } else if (result == null) {
      HapticFeedback.lightImpact();
    }
  }
```

- [ ] **Step 5: `_jumpToGroup()` + `_previewGroup()` 메서드 삭제 (스트립 전용)**

아래 두 메서드 전체 삭제:

```dart
  void _previewGroup(int groupIndex) {
    if (groupIndex == _nav.groupIndex) return;
    _nav.jumpToGroup(groupIndex);
    setState(() {
      _cardState = _CardState.default_;
      _loadedDetail = null;
    });
  }

  void _jumpToGroup(int groupIndex) {
    if (groupIndex != _nav.groupIndex) {
      _nav.jumpToGroup(groupIndex);
    }
    widget.onCameraMove(
      NLatLng(_nav.currentPost.latitude, _nav.currentPost.longitude),
    );
    widget.onGroupChanged?.call(_nav.groupIndex);
    setState(() {
      _cardState = _CardState.default_;
      _loadedDetail = null;
    });
  }
```

- [ ] **Step 6: analyze 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze
```
Expected: `No issues found!`

---

### Task 4: 스트립 테스트 삭제 + 카드 테스트 확인

**Files:**
- Delete: `test/screens/map/bottom_card/map_thumbnail_strip_test.dart`
- Check: `test/screens/map/bottom_card/map_bottom_card_test.dart`

- [ ] **Step 1: 스트립 테스트 파일 삭제**

```bash
rm test/screens/map/bottom_card/map_thumbnail_strip_test.dart
```

- [ ] **Step 2: 카드 테스트가 `MapThumbnailStrip` 참조하지 않는지 확인**

`map_bottom_card_test.dart` 는 `MapThumbnailStrip` 을 import하거나 find하지 않으므로 수정 불필요. 테스트 그대로 통과해야 한다.

- [ ] **Step 3: 전체 테스트 실행**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && \
  flutter test test/service/image/image_service_test.dart \
              test/screens/map/bottom_card/map_bottom_card_test.dart \
              test/screens/map/bottom_card/post_group_navigator_test.dart \
              test/screens/map/bottom_card/relative_time_test.dart
```
Expected: `All tests passed!`

---

### Task 5: 최종 검증 + 단일 커밋

**Files:** 없음 (검증 + 커밋만)

- [ ] **Step 1: flutter analyze 전체 통과**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 2: 전체 테스트 통과**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter test
```
Expected: `All tests passed!`

- [ ] **Step 3: 변경 범위 확인**

```bash
git -C /Users/kwondaeyoung/unimal/app/unimal_flutter diff --stat HEAD
```

변경 예상 파일:
- `lib/service/image/image_service.dart`
- `lib/screens/map/map_naver.dart`
- `lib/screens/map/bottom_card/map_bottom_card.dart`
- `test/service/image/image_service_test.dart` (신규)
- `test/screens/map/bottom_card/map_thumbnail_strip_test.dart` (삭제)

- [ ] **Step 4: 단일 커밋**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && \
  git add lib/service/image/image_service.dart \
          lib/screens/map/map_naver.dart \
          lib/screens/map/bottom_card/map_bottom_card.dart \
          test/service/image/image_service_test.dart && \
  git rm test/screens/map/bottom_card/map_thumbnail_strip_test.dart && \
  git commit -m "$(cat <<'EOF'
feat: 썸네일 스트립 제거, 선택 마커에 파란 링 합성 적용

- addSelectionRing(): 기존 마커 bytes(200x200) → 파란 링 + 핀 꼬리 합성(200x240)
- _applySelectionHighlight(): 핀 아이콘 → 링 이미지로 교체 (비동기 캐시)
- onGroupChanged: 카드 스와이프 시 카메라가 jitter 위치 기준으로 이동
- MapBottomCard: MapThumbnailStrip 및 관련 코드 전체 제거

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```
