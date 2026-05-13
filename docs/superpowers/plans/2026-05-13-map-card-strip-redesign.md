# 지도 카드 + 썸네일 스트립 리디자인 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** peek/full 바텀시트를 완전히 교체 — 마커 탭 시 썸네일 스트립 + 풀와이드 카드(기본/확장)로 전환하고, 카드 좌우 스와이프로 마커 이동, 위로 드래그로 댓글까지 확장.

**Architecture:** `MapThumbnailStrip`(순수 UI)과 개선된 `MapBottomCard`(3단계 카드 + 스트립 통합)로 분리. `PostGroupNavigator`에 그룹 단위 이동 메서드 추가. `getBoardDetail`로 댓글을 지연 로딩하여 상세 페이지 없이 지도 내 완결.

**Tech Stack:** Flutter 3.8+, flutter_naver_map, cached_network_image, BoardApiService.getBoardDetail / createReply (기존 API 재사용)

---

## 파일 구조

| 상태 | 경로 | 역할 |
|------|------|------|
| **신규** | `lib/screens/map/bottom_card/map_thumbnail_strip.dart` | 고정 윈도우 썸네일 스트립 위젯 |
| **신규** | `lib/screens/map/bottom_card/map_card_expanded_content.dart` | 확장 카드 내부 스크롤 영역 (본문+댓글+입력) |
| **신규** | `test/screens/map/bottom_card/map_thumbnail_strip_test.dart` | stripVisibleIndices 단위 테스트 |
| **전체 재작성** | `lib/screens/map/bottom_card/map_bottom_card.dart` | 새 카드 아키텍처 (기본/확장, 스트립 통합) |
| **부분 수정** | `lib/screens/map/bottom_card/post_group_navigator.dart` | nextGroup() / prevGroup() 추가 |
| **부분 수정** | `lib/screens/map/bottom_card/post_image_carousel.dart` | ‹ › 탭 존 추가 |
| **부분 수정** | `test/screens/map/bottom_card/post_group_navigator_test.dart` | nextGroup/prevGroup 테스트 추가 |
| **부분 수정** | `lib/screens/map/map_naver.dart` | 새 카드 파라미터 연결, FAB 위치 조정 |
| **유지** | `lib/screens/map/bottom_card/post_info_section.dart` | 그대로 재사용 |
| **유지** | `lib/screens/map/bottom_card/relative_time.dart` | 그대로 재사용 |

---

## Task 1: `stripVisibleIndices` 순수 함수 + `MapThumbnailStrip` 위젯

**Files:**
- Create: `lib/screens/map/bottom_card/map_thumbnail_strip.dart`
- Create: `test/screens/map/bottom_card/map_thumbnail_strip_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/screens/map/bottom_card/map_thumbnail_strip_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/bottom_card/map_thumbnail_strip.dart';

void main() {
  group('stripVisibleIndices', () {
    test('그룹 5개, 현재 2번 → [0,1,2,3,4] 전체 반환', () {
      expect(stripVisibleIndices(5, 2), [0, 1, 2, 3, 4]);
    });

    test('그룹 10개, 현재 5번 → [3,4,5,6,7] 반환', () {
      expect(stripVisibleIndices(10, 5), [3, 4, 5, 6, 7]);
    });

    test('그룹 3개, 현재 0번 → [0,1,2] (왼쪽 클램프)', () {
      expect(stripVisibleIndices(3, 0), [0, 1, 2]);
    });

    test('그룹 3개, 현재 2번 → [0,1,2] (오른쪽 클램프)', () {
      expect(stripVisibleIndices(3, 2), [0, 1, 2]);
    });

    test('그룹 1개 → [0]', () {
      expect(stripVisibleIndices(1, 0), [0]);
    });

    test('그룹 2개, 현재 1번 → [0,1]', () {
      expect(stripVisibleIndices(2, 1), [0, 1]);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter
flutter test test/screens/map/bottom_card/map_thumbnail_strip_test.dart
```
Expected: `FAILED — Target of URI doesn't exist`

- [ ] **Step 3: `map_thumbnail_strip.dart` 구현**

```dart
// lib/screens/map/bottom_card/map_thumbnail_strip.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:unimal/service/map/models/map_post.dart';

/// 현재 그룹 기준으로 표시할 인덱스 목록 반환 (최대 2+현재+2).
/// 범위 초과 인덱스는 포함하지 않으며, 별도 오버플로 표시 없음.
List<int> stripVisibleIndices(int groupCount, int currentIndex) {
  final result = <int>[];
  for (int offset = -2; offset <= 2; offset++) {
    final idx = currentIndex + offset;
    if (idx >= 0 && idx < groupCount) result.add(idx);
  }
  return result;
}

class MapThumbnailStrip extends StatelessWidget {
  final List<List<MapPost>> groups;
  final int currentGroupIndex;
  final ValueChanged<int> onTap;

  const MapThumbnailStrip({
    super.key,
    required this.groups,
    required this.currentGroupIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final indices = stripVisibleIndices(groups.length, currentGroupIndex);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: indices.map((i) {
          final isActive = i == currentGroupIndex;
          final isTextPost = groups[i].first.fileInfoList.isEmpty;
          final size = isActive ? 36.0 : 26.0;
          final opacity = () {
            final dist = (i - currentGroupIndex).abs();
            return dist == 0 ? 1.0 : dist == 1 ? 0.65 : 0.45;
          }();

          return GestureDetector(
            onTap: () => onTap(i),
            child: Opacity(
              opacity: opacity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: size,
                height: size,
                margin: EdgeInsets.symmetric(horizontal: isActive ? 4 : 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF4D91FF)
                        : isTextPost
                            ? const Color(0xFFFF9F43)
                            : const Color(0xFF555555),
                    width: isActive ? 2.0 : 1.5,
                  ),
                  boxShadow: isActive
                      ? [
                          const BoxShadow(
                            color: Color(0x444D91FF),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.5),
                  child: isTextPost
                      ? Container(
                          color: const Color(0xFF1E1E2E),
                          child: Center(
                            child: Text(
                              '💬',
                              style: TextStyle(fontSize: size * 0.45),
                            ),
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: groups[i].first.fileInfoList.first.fileUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const ColoredBox(
                            color: Color(0xFF2A2A3E),
                          ),
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: Color(0xFF2A2A3E),
                          ),
                        ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
flutter test test/screens/map/bottom_card/map_thumbnail_strip_test.dart
```
Expected: `All tests passed.`

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/map/bottom_card/map_thumbnail_strip.dart \
        test/screens/map/bottom_card/map_thumbnail_strip_test.dart
git commit -m "feat(map): MapThumbnailStrip 위젯 + stripVisibleIndices 테스트 추가"
```

---

## Task 2: `PostGroupNavigator` — `nextGroup()` / `prevGroup()` 추가

**Files:**
- Modify: `lib/screens/map/bottom_card/post_group_navigator.dart` (끝 부분에 2개 메서드 추가)
- Modify: `test/screens/map/bottom_card/post_group_navigator_test.dart` (테스트 추가)

- [ ] **Step 1: 실패하는 테스트 작성**

기존 `test/screens/map/bottom_card/post_group_navigator_test.dart` 파일 끝 `}` 전에 추가:

```dart
    // --- nextGroup / prevGroup ---

    test('nextGroup()은 같은 그룹 내 게시글을 건너뛰고 다음 그룹으로 이동', () {
      final groups = [
        [_post('a1', 1.0, 1.0), _post('a2', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0)],
        [_post('c1', 3.0, 3.0)],
      ];
      final nav = PostGroupNavigator(groups: groups);
      final result = nav.nextGroup();
      expect(result, isTrue);
      expect(nav.groupIndex, 1);
      expect(nav.postIndex, 0);
      expect(nav.currentImageIndex, 0);
    });

    test('nextGroup()이 마지막 그룹에서 null 반환', () {
      final groups = [
        [_post('a1', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups, initialGroupIndex: 1);
      expect(nav.nextGroup(), isNull);
      expect(nav.groupIndex, 1);
    });

    test('prevGroup()은 이전 그룹으로 이동', () {
      final groups = [
        [_post('a1', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0), _post('b2', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups, initialGroupIndex: 1);
      final result = nav.prevGroup();
      expect(result, isTrue);
      expect(nav.groupIndex, 0);
      expect(nav.postIndex, 0);
    });

    test('prevGroup()이 첫 그룹에서 null 반환', () {
      final groups = [
        [_post('a1', 1.0, 1.0)],
        [_post('b1', 2.0, 2.0)],
      ];
      final nav = PostGroupNavigator(groups: groups);
      expect(nav.prevGroup(), isNull);
      expect(nav.groupIndex, 0);
    });
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
flutter test test/screens/map/bottom_card/post_group_navigator_test.dart
```
Expected: `FAILED — nextGroup not defined`

- [ ] **Step 3: `PostGroupNavigator`에 메서드 추가**

`lib/screens/map/bottom_card/post_group_navigator.dart`의 `prev()` 메서드 바로 뒤에 추가:

```dart
  /// 게시글을 건너뛰고 다음 마커 그룹으로 바로 이동.
  /// 다음 그룹이 있으면 true, 없으면 null (경계).
  bool? nextGroup() {
    if (_groupIndex + 1 < groups.length) {
      _groupIndex++;
      _postIndex = 0;
      _imageIndex = 0;
      return true;
    }
    return null;
  }

  /// 게시글을 건너뛰고 이전 마커 그룹으로 바로 이동.
  /// 이전 그룹이 있으면 true, 없으면 null (경계).
  bool? prevGroup() {
    if (_groupIndex > 0) {
      _groupIndex--;
      _postIndex = 0;
      _imageIndex = 0;
      return true;
    }
    return null;
  }
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
flutter test test/screens/map/bottom_card/post_group_navigator_test.dart
```
Expected: `All tests passed.`

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/map/bottom_card/post_group_navigator.dart \
        test/screens/map/bottom_card/post_group_navigator_test.dart
git commit -m "feat(map): PostGroupNavigator에 nextGroup/prevGroup 추가"
```

---

## Task 3: `PostImageCarousel` — ‹ › 탭 존 추가

카드 좌우 스와이프는 마커 이동용. 이미지 내 사진 전환은 탭 존으로만.

**Files:**
- Modify: `lib/screens/map/bottom_card/post_image_carousel.dart`

- [ ] **Step 1: `_buildTapZones()` 추가 후 Stack에 삽입**

`post_image_carousel.dart`의 `build()` 메서드에서 `Stack`의 `children` 끝에 추가:

```dart
// 기존 Stack children 리스트 끝에 추가 (total > 0 이면 항상)
if (total > 1) ...[
  // 왼쪽 탭 존
  Positioned(
    left: 0,
    top: 0,
    bottom: 0,
    width: 44,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_current > 0) {
          _controller.previousPage(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      },
    ),
  ),
  // 오른쪽 탭 존
  Positioned(
    right: 0,
    top: 0,
    bottom: 0,
    width: 44,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_current < total - 1) {
          _controller.nextPage(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      },
    ),
  ),
],
```

- [ ] **Step 2: 빌드 확인**

```bash
flutter analyze lib/screens/map/bottom_card/post_image_carousel.dart
```
Expected: `No issues found.`

- [ ] **Step 3: 커밋**

```bash
git add lib/screens/map/bottom_card/post_image_carousel.dart
git commit -m "feat(map): PostImageCarousel에 이미지 ‹ › 탭 존 추가"
```

---

## Task 4: `MapCardExpandedContent` — 확장 카드 내부 (본문+댓글+입력)

**Files:**
- Create: `lib/screens/map/bottom_card/map_card_expanded_content.dart`

- [ ] **Step 1: 파일 생성**

```dart
// lib/screens/map/bottom_card/map_card_expanded_content.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/board/model/reply_info.dart';
import 'package:unimal/service/map/models/map_post.dart';

/// 확장 카드의 스크롤 가능한 내부 영역.
/// 본문, 댓글 목록, 댓글 입력창을 포함한다.
/// [detail]이 null이면 로딩 중 표시.
class MapCardExpandedContent extends StatefulWidget {
  final MapPost post;
  final BoardPost? detail;
  final bool isLoading;

  const MapCardExpandedContent({
    super.key,
    required this.post,
    required this.detail,
    required this.isLoading,
  });

  @override
  State<MapCardExpandedContent> createState() => _MapCardExpandedContentState();
}

class _MapCardExpandedContentState extends State<MapCardExpandedContent> {
  final _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    await BoardApiService().createReply(widget.post.id, text);
    if (mounted) {
      _commentController.clear();
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 스크롤 가능 영역
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPostInfo(),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2A2A3E), height: 1),
                const SizedBox(height: 12),
                _buildComments(),
              ],
            ),
          ),
        ),
        // 댓글 입력 (하단 고정)
        _buildCommentInput(),
      ],
    );
  }

  Widget _buildPostInfo() {
    final post = widget.post;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목 + 시간
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                post.title.isNotEmpty ? post.title : '제목 없음',
                style: const TextStyle(
                  fontSize: 17,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
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
        if (post.content.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            post.content,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Pretendard',
              color: Color(0xFFD1D5DB),
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.favorite, size: 16, color: Color(0xFFFF6B6B)),
            const SizedBox(width: 4),
            Text('${post.likeCount}',
                style: const TextStyle(fontSize: 13, fontFamily: 'Pretendard', color: Color(0xFF9E9E9E))),
            const SizedBox(width: 16),
            const Icon(Icons.chat_bubble_outline, size: 15, color: Color(0xFF4D91FF)),
            const SizedBox(width: 4),
            Text('${post.replyCount}',
                style: const TextStyle(fontSize: 13, fontFamily: 'Pretendard', color: Color(0xFF9E9E9E))),
          ],
        ),
      ],
    );
  }

  Widget _buildComments() {
    if (widget.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Color(0xFF4D91FF), strokeWidth: 2),
        ),
      );
    }
    final replies = widget.detail?.reply ?? [];
    final visible = replies.where((r) => !r.isDel && !r.reReplyYn).toList();
    if (visible.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '아직 댓글이 없어요',
            style: TextStyle(fontSize: 13, fontFamily: 'Pretendard', color: Color(0xFF555555)),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '댓글 ${visible.length}',
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
            color: Color(0xFF9E9E9E),
          ),
        ),
        const SizedBox(height: 10),
        ...visible.map((r) => _buildReplyItem(r)),
      ],
    );
  }

  Widget _buildReplyItem(ReplyInfo reply) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(imageUrl: reply.profileImage, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.nickname,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE5E7EB),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      relativeTimeFromString(reply.createdAt),
                      style: const TextStyle(fontSize: 11, fontFamily: 'Pretendard', color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  reply.comment,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Pretendard',
                    color: Color(0xFFD1D5DB),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + safeBottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: Color(0xFF252535))),
      ),
      child: Row(
        children: [
          const _Avatar(imageUrl: null, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF252535),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _commentController,
                style: const TextStyle(fontSize: 13, fontFamily: 'Pretendard', color: Colors.white),
                decoration: const InputDecoration.collapsed(
                  hintText: '나도 한 마디...',
                  hintStyle: TextStyle(color: Color(0xFF555555), fontFamily: 'Pretendard'),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendComment,
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4D91FF)),
                  )
                : const Icon(Icons.send_rounded, color: Color(0xFF4D91FF), size: 22),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const _Avatar({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF2A2A3E),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
          : const Icon(Icons.person_outline, size: 18, color: Color(0xFF555555)),
    );
  }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
flutter analyze lib/screens/map/bottom_card/map_card_expanded_content.dart
```
Expected: `No issues found.`

- [ ] **Step 3: 커밋**

```bash
git add lib/screens/map/bottom_card/map_card_expanded_content.dart
git commit -m "feat(map): MapCardExpandedContent — 확장 카드 본문+댓글+입력 위젯 추가"
```

---

## Task 5: `MapBottomCard` 전체 재작성

**Files:**
- Rewrite: `lib/screens/map/bottom_card/map_bottom_card.dart`

- [ ] **Step 1: 파일 전체 교체**

```dart
// lib/screens/map/bottom_card/map_bottom_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:unimal/screens/map/bottom_card/map_card_expanded_content.dart';
import 'package:unimal/screens/map/bottom_card/map_thumbnail_strip.dart';
import 'package:unimal/screens/map/bottom_card/post_group_navigator.dart';
import 'package:unimal/screens/map/bottom_card/post_image_carousel.dart';
import 'package:unimal/screens/map/bottom_card/post_info_section.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/map/models/map_post.dart';

/// 카드 상태: 기본(default_) 또는 확장(expanded).
/// 닫힘은 onClose 콜백으로 부모에서 처리.
enum _CardState { default_, expanded }

/// 지도 마커 탭 시 표시되는 카드 + 썸네일 스트립.
///
/// 레이아웃 (아래에서 위):
///   [카드 본문] ← AnimatedContainer, 높이 변동
///   [썸네일 스트립] ← 카드 바로 위 부유, 확장 시 minTopMargin에 고정
///
/// 제스처:
///   - 핸들 위 드래그(≥60px / 300px/s) → 확장
///   - 핸들 아래 드래그(≥60px / 300px/s) → 기본→닫힘, 확장→기본
///   - 카드 좌우 스와이프(기본 상태만, ≥60px / 300px/s) → 이전/다음 마커
///   - 스트립 썸네일 탭 → 해당 마커로 점프
///   - 이미지 ‹ › 탭 → 같은 게시글 사진 전환 (PostImageCarousel이 처리)
class MapBottomCard extends StatefulWidget {
  final List<List<MapPost>> groups;
  final int initialGroupIndex;
  final ValueChanged<NLatLng> onCameraMove;
  final VoidCallback onClose;

  /// 스트립이 올라갈 수 있는 화면 상단 한계 (검색바+필터 하단).
  /// map_naver.dart에서 safeAreaTop + 약 100px로 전달.
  final double minTopMargin;

  const MapBottomCard({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    required this.onCameraMove,
    required this.onClose,
    required this.minTopMargin,
  });

  @override
  State<MapBottomCard> createState() => _MapBottomCardState();
}

class _MapBottomCardState extends State<MapBottomCard> {
  static const _defaultImageRatio = 0.62;
  static const _defaultTextRatio = 0.38;
  static const _hSwipeMinDistance = 60.0;
  static const _hSwipeMinVelocity = 300.0;
  static const _handleDragThreshold = 60.0;
  static const _handleVelocityThreshold = 300.0;
  static const _stripHeight = 50.0;
  static const _stripCardGap = 8.0;

  late PostGroupNavigator _nav;
  _CardState _cardState = _CardState.default_;
  double _hDragAccum = 0;
  double _handleDragAccum = 0;

  BoardPost? _loadedDetail;
  bool _isLoadingDetail = false;

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
    if (oldWidget.initialGroupIndex != widget.initialGroupIndex ||
        oldWidget.groups != widget.groups) {
      _nav = PostGroupNavigator(
        groups: widget.groups,
        initialGroupIndex: widget.initialGroupIndex,
      );
      _cardState = _CardState.default_;
      _loadedDetail = null;
    }
  }

  bool get _isImagePost => _nav.currentPost.fileInfoList.isNotEmpty;

  double _cardHeight(double screenHeight) {
    final maxCardH = screenHeight - widget.minTopMargin - _stripHeight - _stripCardGap;
    final ratio = _cardState == _CardState.default_
        ? (_isImagePost ? _defaultImageRatio : _defaultTextRatio)
        : 1.0; // expanded fills available space
    return (screenHeight * ratio).clamp(0.0, maxCardH);
  }

  // ── Handle drag (expand / collapse / close) ──────────────────────────

  void _onHandleDragUpdate(DragUpdateDetails d) {
    _handleDragAccum += d.delta.dy;
  }

  void _onHandleDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final drag = _handleDragAccum;
    _handleDragAccum = 0;

    if (_cardState == _CardState.default_) {
      if (drag < -_handleDragThreshold || v < -_handleVelocityThreshold) {
        _loadDetail();
        setState(() => _cardState = _CardState.expanded);
      } else if (drag > _handleDragThreshold || v > _handleVelocityThreshold) {
        widget.onClose();
      }
    } else {
      // expanded → shrink to default
      if (drag > _handleDragThreshold || v > _handleVelocityThreshold) {
        setState(() {
          _cardState = _CardState.default_;
          _loadedDetail = null;
        });
      }
    }
  }

  // ── Horizontal swipe (marker navigation, default state only) ─────────

  void _onHorizDragUpdate(DragUpdateDetails d) {
    _hDragAccum += d.delta.dx;
  }

  void _onHorizDragEnd(DragEndDetails d) {
    if (_cardState == _CardState.expanded) {
      _hDragAccum = 0;
      return;
    }
    final v = d.primaryVelocity ?? 0;
    final drag = _hDragAccum;
    _hDragAccum = 0;

    if (drag > _hSwipeMinDistance || v > _hSwipeMinVelocity) {
      _navigateGroup(-1); // swipe right → prev
    } else if (drag < -_hSwipeMinDistance || v < -_hSwipeMinVelocity) {
      _navigateGroup(1); // swipe left → next
    }
  }

  void _navigateGroup(int direction) {
    final result = direction > 0 ? _nav.nextGroup() : _nav.prevGroup();
    if (result == true) {
      widget.onCameraMove(
        NLatLng(_nav.currentPost.latitude, _nav.currentPost.longitude),
      );
    } else if (result == null) {
      HapticFeedback.lightImpact();
    }
    setState(() {
      _loadedDetail = null;
    });
  }

  void _jumpToGroup(int groupIndex) {
    if (groupIndex == _nav.groupIndex) return;
    _nav.jumpToGroup(groupIndex);
    widget.onCameraMove(
      NLatLng(_nav.currentPost.latitude, _nav.currentPost.longitude),
    );
    setState(() {
      _cardState = _CardState.default_;
      _loadedDetail = null;
    });
  }

  // ── Detail lazy loading ───────────────────────────────────────────────

  Future<void> _loadDetail() async {
    if (_loadedDetail != null) return;
    setState(() => _isLoadingDetail = true);
    try {
      final detail = await BoardApiService().getBoardDetail(_nav.currentPost.id);
      if (mounted) {
        setState(() {
          _loadedDetail = detail;
          _isLoadingDetail = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final cardH = _cardHeight(screenH);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 썸네일 스트립
        MapThumbnailStrip(
          groups: widget.groups,
          currentGroupIndex: _nav.groupIndex,
          onTap: _jumpToGroup,
        ),
        const SizedBox(height: _stripCardGap),
        // 카드 본문
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          height: cardH,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Color(0x44000000), blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _onHorizDragUpdate,
            onHorizontalDragEnd: _onHorizDragEnd,
            onHorizontalDragCancel: () => _hDragAccum = 0,
            child: Column(
              children: [
                // 핸들 (수직 드래그 전용)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _onHandleDragUpdate,
                  onVerticalDragEnd: _onHandleDragEnd,
                  onVerticalDragCancel: () => _handleDragAccum = 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF444455),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                // 카드 내용
                Expanded(
                  child: _cardState == _CardState.expanded
                      ? _buildExpandedContent()
                      : _buildDefaultContent(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 기본 상태 내용 ─────────────────────────────────────────────────────

  Widget _buildDefaultContent() {
    final post = _nav.currentPost;
    if (_isImagePost) return _buildImagePostDefault(post);
    return _buildTextPostDefault(post);
  }

  Widget _buildImagePostDefault(MapPost post) {
    return Column(
      children: [
        PostImageCarousel(
          images: post.fileInfoList,
          initialIndex: _nav.currentImageIndex,
          onIndexChanged: (i) => _nav.updateImageIndex(i),
        ),
        Expanded(
          child: PostInfoSection(
            post: post,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            showDetailButton: false,
          ),
        ),
      ],
    );
  }

  Widget _buildTextPostDefault(MapPost post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 프로필 + 이름 + 시간 + 24h 뱃지
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2A2A3E)),
                clipBehavior: Clip.antiAlias,
                child: post.profileImage != null && post.profileImage!.isNotEmpty
                    ? Image.network(post.profileImage!, fit: BoxFit.cover)
                    : const Icon(Icons.person_outline, size: 18, color: Color(0xFF555555)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.nickname,
                        style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    Text(relativeTimeFromString(post.createdAt),
                        style: const TextStyle(fontSize: 11, fontFamily: 'Pretendard', color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFFF9F4322),
                    border: Border.all(color: const Color(0xFFFF9F4366)),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('24h',
                    style: TextStyle(fontSize: 10, fontFamily: 'Pretendard', color: Color(0xFFFF9F43))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 텍스트 내용
          Expanded(
            child: Text(
              post.content,
              style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Pretendard',
                  color: Color(0xFFD1D5DB),
                  height: 1.5),
              overflow: TextOverflow.fade,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.favorite, size: 15, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 4),
              Text('${post.likeCount}',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Pretendard', color: Color(0xFF9E9E9E))),
              const SizedBox(width: 14),
              const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFF4D91FF)),
              const SizedBox(width: 4),
              Text('${post.replyCount}',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Pretendard', color: Color(0xFF9E9E9E))),
            ],
          ),
        ],
      ),
    );
  }

  // ── 확장 상태 내용 ─────────────────────────────────────────────────────

  Widget _buildExpandedContent() {
    final post = _nav.currentPost;
    return Column(
      children: [
        if (_isImagePost)
          PostImageCarousel(
            images: post.fileInfoList,
            initialIndex: _nav.currentImageIndex,
            onIndexChanged: (i) => _nav.updateImageIndex(i),
          ),
        Expanded(
          child: MapCardExpandedContent(
            post: post,
            detail: _loadedDetail,
            isLoading: _isLoadingDetail,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: `PostInfoSection`에서 `showDetailButton` 파라미터 추가**

`lib/screens/map/bottom_card/post_info_section.dart`의 클래스 선언부 수정:

```dart
class PostInfoSection extends StatelessWidget {
  final MapPost post;
  final EdgeInsets padding;
  final bool showDetailButton; // 추가

  const PostInfoSection({
    super.key,
    required this.post,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
    this.showDetailButton = true, // 추가 (기존 호출 깨지지 않음)
  });
```

그리고 `build()` 안의 "자세히 보기" 버튼 블록을 조건부로 감싸기:

```dart
// 기존 코드:
// const SizedBox(height: 14),
// SizedBox(width: double.infinity, height: 48, child: ElevatedButton(...))
// 아래처럼 변경:
if (showDetailButton) ...[
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
          Text('자세히 보기',
              style: TextStyle(fontSize: 15, fontFamily: 'Pretendard', fontWeight: FontWeight.w700)),
          SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios_rounded, size: 14),
        ],
      ),
    ),
  ),
],
```

- [ ] **Step 3: 빌드 오류 없는지 확인**

```bash
flutter analyze lib/screens/map/bottom_card/
```
Expected: `No issues found.`

- [ ] **Step 4: 커밋**

```bash
git add lib/screens/map/bottom_card/map_bottom_card.dart \
        lib/screens/map/bottom_card/post_info_section.dart
git commit -m "feat(map): MapBottomCard 전체 재작성 — 3단계 카드 + 스트립 + 좌우 마커 스와이프"
```

---

## Task 6: `map_naver.dart` 통합

**Files:**
- Modify: `lib/screens/map/map_naver.dart`

- [ ] **Step 1: `MapBottomCard` 호출부 업데이트**

`map_naver.dart`의 `build()` 메서드에서 `MapBottomCard` 호출부를 아래로 교체.

기존:
```dart
if (_selectedGroupIndex != null)
  Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: MapBottomCard(
      key: ValueKey('group_$_selectedGroupIndex'),
      groups: _postGroups,
      initialGroupIndex: _selectedGroupIndex!,
      onCameraMove: (pos) {
        final update = NCameraUpdate.scrollAndZoomTo(target: pos)
          ..setAnimation(animation: NCameraAnimation.fly, duration: const Duration(milliseconds: 600));
        _mapController?.updateCamera(update);
      },
      onClose: () => setState(() => _selectedGroupIndex = null),
    ),
  ),
```

교체:
```dart
if (_selectedGroupIndex != null)
  Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: MapBottomCard(
      key: ValueKey('group_$_selectedGroupIndex'),
      groups: _postGroups,
      initialGroupIndex: _selectedGroupIndex!,
      minTopMargin: MediaQuery.paddingOf(context).top + 100,
      onCameraMove: (pos) {
        final update = NCameraUpdate.scrollAndZoomTo(target: pos)
          ..setAnimation(
            animation: NCameraAnimation.fly,
            duration: const Duration(milliseconds: 600),
          );
        _mapController?.updateCamera(update);
      },
      onClose: () => setState(() => _selectedGroupIndex = null),
    ),
  ),
```

- [ ] **Step 2: FAB 위치 보정**

카드 높이 기준이 달라졌으므로 FAB bottom 오프셋을 기존 `208`에서 카드 기본 높이 기준으로 수정.

기존 `_isAnyCardOpen ? 208 + 56 : 40 + 56` → 이 값은 이미지 포스트 기본 카드 높이(약 62%)보다 작은 208px로 고정돼 있음. 카드가 커지므로 FAB가 카드 아래에 묻히는 걸 방지하기 위해 `_isAnyCardOpen` 조건 시 screenHeight의 63%로 변경:

```dart
// 공유하기 버튼
Positioned(
  right: 16,
  bottom: _isAnyCardOpen
      ? MediaQuery.sizeOf(context).height * 0.63 + 56
      : 40 + 56,
  child: GestureDetector( ... ),
),
// 내 위치 버튼
Positioned(
  right: 16,
  bottom: _isAnyCardOpen
      ? MediaQuery.sizeOf(context).height * 0.63
      : 40,
  child: AnimatedSwitcher( ... ),
),
```

- [ ] **Step 3: 빌드 확인**

```bash
flutter analyze lib/screens/map/map_naver.dart
```
Expected: `No issues found.`

- [ ] **Step 4: 전체 analyze**

```bash
flutter analyze lib/
```
Expected: `No issues found.`

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/map/map_naver.dart
git commit -m "feat(map): map_naver에 새 MapBottomCard 연결 및 FAB 위치 보정"
```

---

## Task 7: 기기 검증 체크리스트

- [ ] 이미지 포스트 마커 탭 → 카드 올라옴, 썸네일 스트립 표시
- [ ] 스트립 썸네일 탭 → 해당 마커로 카메라 이동, 카드 교체
- [ ] 카드 좌우 스와이프 → 이전/다음 마커 이동, 경계 햅틱
- [ ] 이미지 영역 ‹ › 탭 → 같은 게시글 사진 전환
- [ ] 핸들 위 드래그 → 카드 확장, 본문+댓글 스크롤 가능
- [ ] 확장 카드 댓글 입력 → 전송 후 필드 초기화
- [ ] 핸들 아래 드래그 (확장) → 기본 상태로 복귀
- [ ] 핸들 아래 드래그 (기본) → 카드 닫힘
- [ ] 텍스트 포스트 마커 탭 → 작은 카드, 마커 지도에 보임
- [ ] 지도 탭 → 카드 닫힘, 스트립 사라짐

---

## Self-Review 결과

**스펙 커버리지:**
- ✅ 이미지 포스트 카드 62% / 텍스트 포스트 38%
- ✅ 고정 윈도우 스트립 (2+현재+2, +N 없음)
- ✅ 카드 3단계 (닫힘/기본/확장 88%)
- ✅ 스트립 minTopMargin 고정
- ✅ 좌우 스와이프 = 마커 이동 (기본 상태만)
- ✅ 이미지 탭 존 ‹ ›
- ✅ 확장 시 댓글 지연 로딩 (getBoardDetail)
- ✅ 댓글 입력 (createReply)
- ✅ 햅틱 피드백 경계 처리

**타입 일관성:**
- `PostGroupNavigator.nextGroup()` / `prevGroup()` — Task 2에서 정의, Task 5에서 사용 ✅
- `MapThumbnailStrip(groups, currentGroupIndex, onTap)` — Task 1에서 정의, Task 5에서 사용 ✅
- `PostInfoSection(showDetailButton: false)` — Task 5에서 정의, 사용 ✅
- `BoardApiService().getBoardDetail(id)` — 기존 메서드 그대로 ✅
