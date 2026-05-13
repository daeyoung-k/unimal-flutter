# 지도 바텀시트 카드 UI 리뉴얼 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 지도 핀 탭 시 표시되는 바텀시트를 "이미지 중심 큰 카드 + 좌우 이미지 캐러셀 + 상하 게시글 순회 + 다른 마커로 카메라 이동" 구조로 리뉴얼한다. 이를 통해 "지도 = 메인 피드" 컨셉을 첫 화면에서 전달한다.

**Architecture:** 기존 `_PostInfoCard` 위젯을 제거하고 `lib/screens/map/bottom_card/` 폴더에 4개 컴포넌트 신설. peek(30%)/full(55%) 2단계 스냅 포인트. 좌우=이미지 캐러셀, 상하=게시글 순회(같은 좌표 우선 → 다른 마커로 카메라 이동). 제스처 충돌은 `ClampingScrollPhysics` 가로 PageView + 부모 `GestureDetector` 세로 처리로 분리.

**Tech Stack:** Flutter 3.8.0, Dart, GetX 4.7.2, flutter_naver_map 1.4.4, cached_network_image 3.4.1. `intl` 미사용 — `DateTime`/`Duration` 표준 라이브러리로 상대 시간 계산.

**Spec:** `docs/superpowers/specs/2026-05-13-map-bottomsheet-redesign-design.md`

---

## File Structure

| 작업 | 경로 | 책임 |
|------|------|------|
| Create | `lib/screens/map/bottom_card/relative_time.dart` | `DateTime` → "N분 전" 문자열 변환 |
| Create | `lib/screens/map/bottom_card/post_group_navigator.dart` | 그룹 인덱스/게시글 인덱스 상태, next()/prev() 로직 |
| Create | `lib/screens/map/bottom_card/post_image_carousel.dart` | 좌우 PageView, 이미지 캐러셀 |
| Create | `lib/screens/map/bottom_card/post_info_section.dart` | 제목·주소·시간·내용·액션 행 |
| Create | `lib/screens/map/bottom_card/map_bottom_card.dart` | 시트 컨테이너, peek/full 상태, 제스처 라우터 |
| Create | `test/screens/map/bottom_card/relative_time_test.dart` | 시간 경계값 테스트 |
| Create | `test/screens/map/bottom_card/post_group_navigator_test.dart` | next/prev/경계 케이스 테스트 |
| Modify | `lib/screens/map/map_naver.dart` | `_selectedPosts` 단일 그룹 상태 → `_postGroups` 전체 + `_selectedGroupIndex`. `_PostInfoCard` 위젯 및 관련 helper 제거. `MapBottomCard` 사용 |

---

## Task 1: relativeTime 헬퍼 (TDD)

**Files:**
- Create: `lib/screens/map/bottom_card/relative_time.dart`
- Test: `test/screens/map/bottom_card/relative_time_test.dart`

- [ ] **Step 1: Write failing test**

`test/screens/map/bottom_card/relative_time_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';

void main() {
  group('relativeTime', () {
    final now = DateTime(2026, 5, 13, 12, 0, 0);

    test('returns "방금 전" for < 1 minute', () {
      expect(relativeTime(now.subtract(const Duration(seconds: 30)), reference: now), '방금 전');
      expect(relativeTime(now.subtract(const Duration(seconds: 59)), reference: now), '방금 전');
    });

    test('returns "N분 전" for 1 minute to 59 minutes', () {
      expect(relativeTime(now.subtract(const Duration(minutes: 1)), reference: now), '1분 전');
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), reference: now), '5분 전');
      expect(relativeTime(now.subtract(const Duration(minutes: 59)), reference: now), '59분 전');
    });

    test('returns "N시간 전" for 1 hour to 23 hours', () {
      expect(relativeTime(now.subtract(const Duration(hours: 1)), reference: now), '1시간 전');
      expect(relativeTime(now.subtract(const Duration(hours: 23)), reference: now), '23시간 전');
    });

    test('returns "N일 전" for 1 day to 6 days', () {
      expect(relativeTime(now.subtract(const Duration(days: 1)), reference: now), '1일 전');
      expect(relativeTime(now.subtract(const Duration(days: 6)), reference: now), '6일 전');
    });

    test('returns "YYYY-MM-DD" for 7 days or more', () {
      expect(relativeTime(DateTime(2026, 5, 1), reference: now), '2026-05-01');
      expect(relativeTime(DateTime(2025, 12, 31), reference: now), '2025-12-31');
    });

    test('fromString parses ISO and falls back to "방금 전" on failure', () {
      expect(relativeTimeFromString('2026-05-13T11:55:00', reference: now), '5분 전');
      expect(relativeTimeFromString('invalid', reference: now), '방금 전');
      expect(relativeTimeFromString('', reference: now), '방금 전');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/map/bottom_card/relative_time_test.dart`
Expected: 컴파일 에러 — `Target of URI doesn't exist: 'package:unimal/screens/map/bottom_card/relative_time.dart'`

- [ ] **Step 3: Write minimal implementation**

`lib/screens/map/bottom_card/relative_time.dart`:

```dart
/// Returns a Korean relative-time string for [when], compared against [reference]
/// (defaults to `DateTime.now()`).
///
/// Rules:
/// - `< 1분` → "방금 전"
/// - `< 60분` → "N분 전"
/// - `< 24시간` → "N시간 전"
/// - `< 7일` → "N일 전"
/// - 그 외 → "YYYY-MM-DD"
String relativeTime(DateTime when, {DateTime? reference}) {
  final now = reference ?? DateTime.now();
  final diff = now.difference(when);

  if (diff.inSeconds < 60) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';

  final y = when.year.toString().padLeft(4, '0');
  final m = when.month.toString().padLeft(2, '0');
  final d = when.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses an ISO-8601 string and returns [relativeTime].
/// Returns "방금 전" if parsing fails or input is empty.
String relativeTimeFromString(String iso, {DateTime? reference}) {
  if (iso.isEmpty) return '방금 전';
  try {
    return relativeTime(DateTime.parse(iso), reference: reference);
  } catch (_) {
    return '방금 전';
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/map/bottom_card/relative_time_test.dart`
Expected: `All tests passed!` (6 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/map/bottom_card/relative_time.dart test/screens/map/bottom_card/relative_time_test.dart
git commit -m "$(cat <<'EOF'
feat(map): 상대 시간 헬퍼 relativeTime 추가

DateTime을 "5분 전" 형식 한국어 문자열로 변환. 경계값(<1분/<60분/<24시간/<7일)
별 분기와 ISO 문자열 파싱 실패 시 "방금 전" fallback 처리. 6개 단위 테스트.
EOF
)"
```

---

## Task 2: PostGroupNavigator 클래스 (TDD)

**Files:**
- Create: `lib/screens/map/bottom_card/post_group_navigator.dart`
- Test: `test/screens/map/bottom_card/post_group_navigator_test.dart`

- [ ] **Step 1: Write failing test**

`test/screens/map/bottom_card/post_group_navigator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/bottom_card/post_group_navigator.dart';
import 'package:unimal/service/board/model/file_info.dart';
import 'package:unimal/service/map/models/map_post.dart';

MapPost _post(String id, double lat, double lng) => MapPost(
  id: id,
  nickname: 'tester',
  profileImage: null,
  title: id,
  content: '',
  streetName: '',
  latitude: lat,
  longitude: lng,
  createdAt: '2026-05-13T12:00:00',
  fileInfoList: <FileInfo>[],
  likeCount: 0,
  replyCount: 0,
  score: 0,
  isOwner: false,
);

void main() {
  group('PostGroupNavigator', () {
    test('next() within the same group does not jump camera', () {
      final groups = [
        [_post('a1', 1.0, 1.0), _post('a2', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups);

      expect(nav.currentPost.id, 'a1');
      final jumped = nav.next();
      expect(jumped, isFalse);
      expect(nav.currentPost.id, 'a2');
    });

    test('next() across groups jumps camera and resets postIndex/image', () {
      final groups = [
        [_post('a1', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0), _post('b2', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups, currentImageIndex: 3);

      final jumped = nav.next();
      expect(jumped, isTrue);
      expect(nav.currentPost.id, 'b1');
      expect(nav.currentImageIndex, 0);
    });

    test('next() at the very end returns null sentinel and keeps position', () {
      final groups = [
        [_post('a1', 1.0, 1.0)],
      ];
      final nav = PostGroupNavigator(groups: groups);
      expect(nav.next(), isNull);
      expect(nav.currentPost.id, 'a1');
    });

    test('prev() within group does not jump camera', () {
      final groups = [
        [_post('a1', 1.0, 1.0), _post('a2', 1.0, 1.0)],
      ];
      final nav = PostGroupNavigator(groups: groups, initialGroupIndex: 0, initialPostIndex: 1);
      expect(nav.prev(), isFalse);
      expect(nav.currentPost.id, 'a1');
    });

    test('prev() across groups jumps camera and goes to last post of prev group', () {
      final groups = [
        [_post('a1', 1.0, 1.0), _post('a2', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups, initialGroupIndex: 1);
      final jumped = nav.prev();
      expect(jumped, isTrue);
      expect(nav.currentPost.id, 'a2');
      expect(nav.currentImageIndex, 0);
    });

    test('prev() at very beginning returns null sentinel', () {
      final groups = [
        [_post('a1', 1.0, 1.0)],
      ];
      final nav = PostGroupNavigator(groups: groups);
      expect(nav.prev(), isNull);
    });

    test('jumpToGroup resets indices and reports group coordinate', () {
      final groups = [
        [_post('a1', 1.0, 1.0), _post('a2', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups, currentImageIndex: 4);
      nav.jumpToGroup(1);
      expect(nav.currentPost.id, 'b1');
      expect(nav.currentImageIndex, 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/map/bottom_card/post_group_navigator_test.dart`
Expected: 컴파일 에러 — `'package:unimal/screens/map/bottom_card/post_group_navigator.dart'` 없음

- [ ] **Step 3: Write implementation**

`lib/screens/map/bottom_card/post_group_navigator.dart`:

```dart
import 'package:unimal/service/map/models/map_post.dart';

/// Holds navigation state for grouped posts on the map.
///
/// Groups are lists of [MapPost] at the same coordinate, ordered by score desc.
/// Sweeping next()/prev() moves within the current group first, and only
/// jumps to the next/previous group when the current group is exhausted.
///
/// Returns:
/// - `false` : moved within the same group (no camera jump needed)
/// - `true`  : crossed a group boundary (caller should move camera)
/// - `null`  : at the absolute beginning/end (caller may bounce)
class PostGroupNavigator {
  final List<List<MapPost>> groups;
  int _groupIndex;
  int _postIndex;
  int _imageIndex;

  PostGroupNavigator({
    required this.groups,
    int initialGroupIndex = 0,
    int initialPostIndex = 0,
    int currentImageIndex = 0,
  })  : _groupIndex = initialGroupIndex,
        _postIndex = initialPostIndex,
        _imageIndex = currentImageIndex {
    assert(groups.isNotEmpty, 'PostGroupNavigator requires non-empty groups');
  }

  int get groupIndex => _groupIndex;
  int get postIndex => _postIndex;
  int get currentImageIndex => _imageIndex;
  set currentImageIndex(int v) => _imageIndex = v;

  MapPost get currentPost => groups[_groupIndex][_postIndex];
  List<MapPost> get currentGroup => groups[_groupIndex];

  /// Moves to the next post. Returns `false` if within same group,
  /// `true` if crossed group boundary, `null` if already at the end.
  bool? next() {
    if (_postIndex + 1 < groups[_groupIndex].length) {
      _postIndex++;
      _imageIndex = 0;
      return false;
    }
    if (_groupIndex + 1 < groups.length) {
      _groupIndex++;
      _postIndex = 0;
      _imageIndex = 0;
      return true;
    }
    return null;
  }

  /// Moves to the previous post. Returns `false` if within same group,
  /// `true` if crossed group boundary, `null` if already at the beginning.
  bool? prev() {
    if (_postIndex > 0) {
      _postIndex--;
      _imageIndex = 0;
      return false;
    }
    if (_groupIndex > 0) {
      _groupIndex--;
      _postIndex = groups[_groupIndex].length - 1;
      _imageIndex = 0;
      return true;
    }
    return null;
  }

  /// Jump to a specific group (e.g., when user taps a different marker).
  void jumpToGroup(int groupIndex) {
    assert(groupIndex >= 0 && groupIndex < groups.length);
    _groupIndex = groupIndex;
    _postIndex = 0;
    _imageIndex = 0;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/map/bottom_card/post_group_navigator_test.dart`
Expected: `All tests passed!` (7 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/map/bottom_card/post_group_navigator.dart test/screens/map/bottom_card/post_group_navigator_test.dart
git commit -m "$(cat <<'EOF'
feat(map): PostGroupNavigator 그룹 순회 클래스 추가

같은 좌표 우선 → 다른 좌표로 이동하는 next/prev 로직 캡슐화.
그룹 경계 여부를 bool?로 반환해 카메라 이동 필요 여부 판단 가능.
7개 단위 테스트로 boundary 케이스 검증.
EOF
)"
```

---

## Task 3: PostImageCarousel 위젯

**Files:**
- Create: `lib/screens/map/bottom_card/post_image_carousel.dart`

- [ ] **Step 1: Implement the widget**

`lib/screens/map/bottom_card/post_image_carousel.dart`:

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:unimal/service/board/model/file_info.dart';

/// Horizontal carousel of post images. Uses [ClampingScrollPhysics] so it
/// does NOT compete with the parent's vertical drag gesture (no overscroll
/// transferred to ancestors).
class PostImageCarousel extends StatefulWidget {
  final List<FileInfo> images;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;

  const PostImageCarousel({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.onIndexChanged,
  });

  @override
  State<PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<PostImageCarousel> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.images.isEmpty ? 0 : widget.images.length - 1);
    _controller = PageController(initialPage: _current);
  }

  @override
  void didUpdateWidget(covariant PostImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 게시글 전환 시 부모가 initialIndex를 0으로 줄 수 있으므로 동기화
    if (widget.initialIndex != _current && _controller.hasClients) {
      _current = widget.initialIndex.clamp(0, widget.images.isEmpty ? 0 : widget.images.length - 1);
      _controller.jumpToPage(_current);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFF1F3F5),
        child: const Center(
          child: Icon(Icons.image_outlined, size: 48, color: Color(0xFFBDBDBD)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return AspectRatio(aspectRatio: 1, child: _placeholder());
    }

    final total = widget.images.length;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            physics: const ClampingScrollPhysics(),
            itemCount: total,
            onPageChanged: (i) {
              setState(() => _current = i);
              widget.onIndexChanged?.call(i);
            },
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: widget.images[index].fileUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              );
            },
          ),
          // 우상단 N / total 뱃지 (단일 이미지면 숨김)
          if (total > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xCC1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_current + 1} / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          // 하단 도트 인디케이터 (단일 이미지면 숨김)
          if (total > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(total, (i) {
                  final active = i == _current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF4D91FF) : const Color(0x66FFFFFF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyze**

Run: `flutter analyze lib/screens/map/bottom_card/post_image_carousel.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/map/bottom_card/post_image_carousel.dart
git commit -m "$(cat <<'EOF'
feat(map): PostImageCarousel 좌우 이미지 캐러셀 위젯 추가

ClampingScrollPhysics로 부모의 세로 드래그와 제스처 충돌 회피.
빈 리스트/로드 실패는 placeholder. 1장이면 인디케이터 숨김.
EOF
)"
```

---

## Task 4: PostInfoSection 위젯

**Files:**
- Create: `lib/screens/map/bottom_card/post_info_section.dart`

- [ ] **Step 1: Implement the widget**

`lib/screens/map/bottom_card/post_info_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';
import 'package:unimal/service/map/models/map_post.dart';

/// Renders title, address, relative time, content, like/reply counts,
/// and the full-width "자세히 보기" button.
class PostInfoSection extends StatelessWidget {
  final MapPost post;
  final EdgeInsets padding;

  const PostInfoSection({
    super.key,
    required this.post,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 제목 + 시간
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                relativeTimeFromString(post.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Pretendard',
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
          // 주소
          if (post.streetName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF9E9E9E)),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    post.streetName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                      color: Color(0xFF9E9E9E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          // 내용
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Pretendard',
                color: Color(0xFF374151),
                height: 1.4,
              ),
            ),
          ],
          // 좋아요 · 댓글
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.favorite, size: 16, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 4),
              Text(
                '${post.likeCount}',
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Pretendard',
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.chat_bubble_outline, size: 15, color: Color(0xFF4D91FF)),
              const SizedBox(width: 4),
              Text(
                '${post.replyCount}',
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Pretendard',
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
          // 자세히 보기 — 전체 너비 큰 파란 버튼
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Get.toNamed('/detail-board', parameters: {'id': post.id}),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4D91FF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '자세히 보기',
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyze**

Run: `flutter analyze lib/screens/map/bottom_card/post_info_section.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/map/bottom_card/post_info_section.dart
git commit -m "$(cat <<'EOF'
feat(map): PostInfoSection 게시글 정보·액션 행 위젯 추가

제목·주소·상대시간·내용·좋아요·댓글·자세히보기 큰 파란 버튼.
자세히 보기 → /detail-board 라우팅. relativeTime 헬퍼 사용.
EOF
)"
```

---

## Task 5: MapBottomCard 위젯 (시트 + 제스처 라우터)

**Files:**
- Create: `lib/screens/map/bottom_card/map_bottom_card.dart`

- [ ] **Step 1: Implement the widget**

`lib/screens/map/bottom_card/map_bottom_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:unimal/screens/map/bottom_card/post_group_navigator.dart';
import 'package:unimal/screens/map/bottom_card/post_image_carousel.dart';
import 'package:unimal/screens/map/bottom_card/post_info_section.dart';
import 'package:unimal/service/map/models/map_post.dart';

/// 2-stage snap sheet: peek (~30%) and full (~55%).
///
/// Gestures:
/// - peek: 위 드래그(≥60px) → full, 아래 드래그(≥60px) → onClose, 탭 → full
/// - full: 위 스와이프(vel ≥ 300 px/s 또는 drag ≥ 80px) → next post,
///         아래 스와이프(동일 임계값) → prev post
/// - 핸들 탭 → onClose
///
/// 좌우 스와이프는 자식 [PostImageCarousel]이 흡수하여 시트로 전달되지 않음.
enum _SheetState { peek, full }

class MapBottomCard extends StatefulWidget {
  final List<List<MapPost>> groups;
  final int initialGroupIndex;
  final ValueChanged<NLatLng> onCameraMove;
  final VoidCallback onClose;

  const MapBottomCard({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    required this.onCameraMove,
    required this.onClose,
  });

  @override
  State<MapBottomCard> createState() => _MapBottomCardState();
}

class _MapBottomCardState extends State<MapBottomCard> with SingleTickerProviderStateMixin {
  static const double _peekRatio = 0.30;
  static const double _fullRatio = 0.55;
  static const double _peekDragThreshold = 60;
  static const double _postSwipeMinVelocity = 300;
  static const double _postSwipeMinDistance = 80;

  late PostGroupNavigator _nav;
  _SheetState _state = _SheetState.peek;
  double _accumulatedDrag = 0;

  @override
  void initState() {
    super.initState();
    _nav = PostGroupNavigator(
      groups: widget.groups,
      initialGroupIndex: widget.initialGroupIndex,
    );
  }

  @override
  void didUpdateWidget(covariant MapBottomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부에서 다른 마커 탭으로 진입 시 그룹 인덱스 동기화
    if (oldWidget.initialGroupIndex != widget.initialGroupIndex ||
        oldWidget.groups != widget.groups) {
      _nav = PostGroupNavigator(
        groups: widget.groups,
        initialGroupIndex: widget.initialGroupIndex,
      );
      setState(() => _state = _SheetState.peek);
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _accumulatedDrag += details.delta.dy;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final drag = _accumulatedDrag;
    _accumulatedDrag = 0;

    if (_state == _SheetState.peek) {
      if (drag <= -_peekDragThreshold) {
        setState(() => _state = _SheetState.full);
      } else if (drag >= _peekDragThreshold) {
        widget.onClose();
      }
      return;
    }

    // full 상태: 위 스와이프 = 다음, 아래 스와이프 = 이전
    final isUpSwipe = drag <= -_postSwipeMinDistance || velocity <= -_postSwipeMinVelocity;
    final isDownSwipe = drag >= _postSwipeMinDistance || velocity >= _postSwipeMinVelocity;

    if (isUpSwipe) {
      final result = _nav.next();
      if (result == true) {
        widget.onCameraMove(NLatLng(_nav.currentPost.latitude, _nav.currentPost.longitude));
      }
      setState(() {});
    } else if (isDownSwipe) {
      final result = _nav.prev();
      if (result == true) {
        widget.onCameraMove(NLatLng(_nav.currentPost.latitude, _nav.currentPost.longitude));
      }
      setState(() {});
    }
  }

  void _handleHandleTap() => widget.onClose();

  void _handleCardTap() {
    if (_state == _SheetState.peek) {
      setState(() => _state = _SheetState.full);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = (_state == _SheetState.peek ? _peekRatio : _fullRatio) * size.height;
    final post = _nav.currentPost;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        onTap: _handleCardTap,
        child: Column(
          children: [
            // 핸들
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleHandleTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // 본문
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    PostImageCarousel(
                      images: post.fileInfoList,
                      initialIndex: _nav.currentImageIndex,
                      onIndexChanged: (i) => _nav.updateImageIndex(i),
                    ),
                    PostInfoSection(post: post),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyze**

Run: `flutter analyze lib/screens/map/bottom_card/`
Expected: `No issues found!` (4 files in folder)

- [ ] **Step 3: Commit**

```bash
git add lib/screens/map/bottom_card/map_bottom_card.dart
git commit -m "$(cat <<'EOF'
feat(map): MapBottomCard 시트 컨테이너 + 제스처 라우터 추가

peek(30%)/full(55%) 2단계 스냅. peek↔full 전환 임계값 60px,
게시글 전환 임계값 80px·300px/s. 그룹 경계 넘을 때만 카메라 이동
콜백 호출. 좌우 스와이프는 자식 캐러셀이 흡수.
EOF
)"
```

---

## Task 6: map_naver.dart 통합

**Files:**
- Modify: `lib/screens/map/map_naver.dart`

> **참고:** 이 task는 단일 파일에 여러 영역을 수정하므로 step별로 작은 변경을 누적한다. 각 step 후 `flutter analyze lib/screens/map/map_naver.dart`가 깨끗하지 않으면 그 step 내에서 수정한다.

- [ ] **Step 1: 상태 필드 마이그레이션 (단일 그룹 → 전체 그룹 + 인덱스)**

`lib/screens/map/map_naver.dart`:

기존:
```dart
List<MapPost> _selectedPosts = [];
```

새로 (같은 줄 교체):
```dart
List<List<MapPost>> _postGroups = [];
int? _selectedGroupIndex;
List<MapPost> get _selectedPosts =>
    _selectedGroupIndex == null ? const [] : _postGroups[_selectedGroupIndex!];
```

> 일부 위치(`_isAnyCardOpen` 등)에서 `_selectedPosts.isNotEmpty`를 사용 중이므로 getter로 보존해 변경 표면을 최소화한다.

- [ ] **Step 2: 마커 생성 루프에서 전체 그룹을 멤버에 저장**

map_naver.dart의 마커 생성 부분에서 `grouped` 변수를 인스턴스 필드에 보관하도록 수정.

165~169줄 영역 (현재):
```dart
final Map<String, List<MapPost>> grouped = {};
for (final post in posts) {
  final key = '${post.latitude.toStringAsFixed(3)},${post.longitude.toStringAsFixed(3)}';
  grouped.putIfAbsent(key, () => []).add(post);
}
```

직후에 추가 (새 줄):
```dart
final groupsList = grouped.values.map((g) {
  g.sort((a, b) => b.score.compareTo(a.score));
  return g;
}).toList();
// 클래스 멤버 _postGroups에 보관 (각 그룹은 좌표 기준, score 내림차순 정렬됨)
_postGroups = groupsList;
```

그리고 `for (final postsAtLocation in grouped.values)` 루프(현재 171줄)를 `for (var idx = 0; idx < _postGroups.length; idx++) { final postsAtLocation = _postGroups[idx];` 로 교체하고 closure 안에서 `idx`를 캡처하도록 변경.

마커 탭 핸들러 (현재 205~214줄)는:
```dart
marker.setOnTapListener((_) {
  _focusNode.unfocus();
  setState(() {
    _searchResults = [];
    _selectedSymbol = null;
    _selectedPlace = null;
    _isLoadingPlace = false;
    _selectedGroupIndex = idx;
  });
});
```
로 교체한다. (기존 `_selectedPosts = postsAtLocation` 라인 제거)

- [ ] **Step 3: `_selectedPosts = []` 리셋 지점들을 `_selectedGroupIndex = null` 로 변경**

map_naver.dart의 다른 리셋 위치 (현재 273줄, 341줄)에서 `_selectedPosts = [];` 를 `_selectedGroupIndex = null;` 로 변경. (getter가 빈 리스트를 반환하므로 외부 동작은 동일.)

- [ ] **Step 4: 카드 표시 영역을 MapBottomCard로 교체**

map_naver.dart 600~620줄 영역의 `AnimatedPositioned` + `_PostInfoCard` 블록을 다음으로 교체:

```dart
// 마커 탭 시 바텀시트 카드
if (_selectedGroupIndex != null)
  Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: MapBottomCard(
      key: ValueKey('group_${_selectedGroupIndex}'),
      groups: _postGroups,
      initialGroupIndex: _selectedGroupIndex!,
      onCameraMove: (pos) {
        // 기존 코드(map_naver.dart:242, 279) 의 scrollAndZoomTo 패턴 따름.
        // zoom 인자 미지정 시 현재 줌 유지 (flutter_naver_map 1.4.4 기본 동작).
        final update = NCameraUpdate.scrollAndZoomTo(target: pos)
          ..setAnimation(animation: NCameraAnimation.fly, duration: const Duration(milliseconds: 600));
        _mapController?.updateCamera(update);
      },
      onClose: () => setState(() => _selectedGroupIndex = null),
    ),
  ),
```

`import 'package:unimal/screens/map/bottom_card/map_bottom_card.dart';` 를 파일 상단 import에 추가.

- [ ] **Step 5: 기존 `_PostInfoCard` 클래스와 관련 helper 제거**

map_naver.dart 753줄~파일 끝까지의 `_PostInfoCard` / `_PostInfoCardState` 클래스 전체 삭제.

state 클래스의 `_onCardDragUpdate`, `_onCardDragEnd`, `_cardDragOffset` 같이 이 카드 전용 helper가 있다면 같이 제거. (단, `_PlaceInfoCard` 가 같은 helper를 공유한다면 유지.) 공유 여부는 grep으로 확인:

Run: `grep -n "_cardDragOffset\|_onCardDragUpdate\|_onCardDragEnd\|_closeAllCards" lib/screens/map/map_naver.dart`

- 공유이면 그대로 유지
- 게시글 카드 전용이면 함께 삭제

(_PlaceInfoCard는 onDragUpdate/onDragEnd 콜백을 받고 있어 helper를 공유할 가능성이 크다. 따라서 안전하게 유지하고, MapBottomCard 사용처에서는 더 이상 호출하지 않는 것만 확인한다.)

- [ ] **Step 6: 전체 파일 analyze 통과 확인**

Run: `flutter analyze lib/screens/map/map_naver.dart lib/screens/map/bottom_card/`
Expected: `No issues found!`

만약 unused import/변수 경고가 있으면 그 step 내에서 제거.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/map/map_naver.dart
git commit -m "$(cat <<'EOF'
feat(map): 지도 화면 통합 - MapBottomCard 사용

_selectedPosts(단일 그룹) → _postGroups + _selectedGroupIndex로 변경.
기존 _PostInfoCard 위젯 및 관련 helper 제거하고 MapBottomCard로 교체.
마커 탭 시 그룹 인덱스 설정, 카메라 이동 콜백으로 그룹 간 전환 처리.
EOF
)"
```

---

## Task 7: 메모리·노션 동기화 + 디바이스 검증 안내

**Files:**
- Modify: `/Users/marketdesignrs/.claude/projects/-Users-marketdesignrs/memory/stomap-gesture-semantics.md`
- Modify: 노션 페이지 `35fb8001e5ba8030b949f352863e0c79`

- [ ] **Step 1: 메모리 파일 업데이트 — gesture 충돌 해결 표기**

`/Users/marketdesignrs/.claude/projects/-Users-marketdesignrs/memory/stomap-gesture-semantics.md` 의 "현재 구현과의 충돌" 섹션을 다음으로 교체:

```markdown
**현재 구현 상태**:
- 좌우 스와이프 = 같은 게시글 내 이미지 캐러셀 ✅ (`PostImageCarousel`)
- 상하 스와이프 = 같은 좌표 우선 → 다른 마커로 카메라 이동 ✅ (`MapBottomCard` + `PostGroupNavigator`)
- 바텀시트 닫기 = 핸들 탭 또는 peek 상태에서 아래 드래그 ✅
```

- [ ] **Step 2: 노션 로드맵 1️⃣ 체크리스트에 완료 항목 추가**

노션 페이지의 `## 1️⃣ 지도 바텀시트 UX 개선 🚧 진행 중` 체크리스트에 다음 두 줄을 ✅로 추가:

- ✅ **이미지 중심 바텀시트 + 좌우 캐러셀** — `MapBottomCard` / `PostImageCarousel` 신설 *(YYYY-MM-DD)*
- ✅ **상하 스와이프 다음 게시글 + 카메라 이동** — `PostGroupNavigator` 그룹 순회 *(YYYY-MM-DD)*

(YYYY-MM-DD는 실제 작업 완료 날짜로 치환.)

- [ ] **Step 3: 사용자에게 디바이스 테스트 시나리오 제시**

사용자에게 다음 시나리오 직접 검증 요청:

1. 핀 탭 → peek 카드 표시 (~30% 높이) 확인
2. peek 상태에서 위 드래그 → full 전환 (~55% 높이)
3. peek 상태에서 아래 드래그 → 닫힘
4. peek 상태에서 카드 탭 → full 전환
5. full 상태에서 좌우 스와이프 → 이미지 캐러셀 (1/N 뱃지 + 도트 변화)
6. full 상태에서 위 스와이프 → 같은 좌표 다음 게시글 (이미지 0번부터 시작)
7. 같은 좌표 끝에서 위 스와이프 → 다른 마커로 카메라 부드럽게 이동
8. full 상태에서 아래 스와이프 → 이전 게시글 (대칭 동작)
9. full 상태에서 핸들 탭 → 닫힘
10. 자세히 보기 버튼 탭 → `/detail-board` 진입
11. 이미지 없는 게시글 (file_info_list 빈) → placeholder 표시
12. 다른 마커 탭 → 새 그룹으로 전환, 카메라 이동

- [ ] **Step 4: Commit memory/노션 변경 (메모리는 git 외부이므로 생략 가능)**

```bash
# 노션은 API로 업데이트했으므로 git 커밋 대상 없음
# 메모리 파일은 /Users/marketdesignrs/.claude/... 외부 경로라 unimal-flutter git 외부
# 별도 커밋 불필요
```

이 task는 실제 코드 변경이 없으므로 git 커밋 없이 완료한다.

---

## Verification Commands

작업 전체 완료 후 일괄 확인:

```bash
# 전체 analyze
flutter analyze lib/screens/map/ lib/service/map/ test/screens/map/

# 단위 테스트
flutter test test/screens/map/bottom_card/

# 커밋 흐름
git log --oneline -10
```

Expected:
- analyze: `No issues found!` (변경한 파일 기준)
- tests: 모든 테스트 통과 (relativeTime 6개 + PostGroupNavigator 7개)
- log: 6개 커밋 누적 (Task 1~6, Task 7은 커밋 없음)
