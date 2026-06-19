# 마이페이지 UI 개선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `screens/profile/profile.dart`(ProfileScreens)를 카드 기반 UI로 재구성하고, 스토리 목록 화면 신설 및 게시글 상세 바텀시트 재사용 추출.

**Architecture:** `profile.dart`를 회색 배경 + 카드 레이아웃으로 전면 재구성. `PostDetailSheet`를 신규 추출해 BoardPost→MapPost 어댑터를 통해 기존 `MapCardExpandedContent`를 재사용. `story_list.dart` 공용 목록 화면에서 myStories/likedStories 모드 분기.

**Tech Stack:** Flutter, GetX, AppColors tokens, BoardApiService, MapCardExpandedContent

---

## 파일 목록

| 파일 | 작업 |
|---|---|
| `lib/theme/app_colors.dart` | `accentCoral` 토큰 추가, `light.background` → `#F7F8FA` |
| `lib/service/board/board_api_service.dart` | `getMyLikedTotal()`, `getMyLikedPostList({page,size})` 추가 |
| `lib/screens/profile/mypage/post_detail_sheet.dart` | 신규: boardId → DraggableScrollableSheet + MapCardExpandedContent |
| `lib/screens/profile/mypage/story_thumbnail_card.dart` | 신규: 100×128 썸네일 카드(이미지/텍스트/숏츠) |
| `lib/screens/profile/mypage/story_list.dart` | 신규: 공용 목록 화면 (myStories/likedStories) |
| `lib/screens/profile/profile.dart` | 전면 재구성: 히어로카드/스트립/메뉴/더보기 |
| `lib/screens/navigation/app_routes.dart` | `/story-list` 라우트 추가 |
| `lib/screens/profile/mypage/mypage.dart` | 하드코딩 색 → AppColors 토큰 치환 |

---

## Task 1: AppColors 토큰 업데이트

**Files:**
- Modify: `lib/theme/app_colors.dart`

- [ ] **Step 1: `accentCoral` 필드 추가 및 `light.background` 변경**

`app_colors.dart`에서 아래 변경 적용:

1. `AppColors` 클래스에 `accentCoral` 필드 추가 (기존 `accent` 필드 아래):
```dart
/// 좋아요 하트 코랄 색.
final Color accentCoral;
```

2. 생성자 파라미터에 `required this.accentCoral;` 추가

3. `light` 인스턴스:
   - `background: Color(0xFFF7F8FA),`  (기존 `Color(0xFFFFFFFF)` → 변경)
   - `accentCoral: Color(0xFFFF6B6B),` 추가

4. `dark` 인스턴스:
   - `background` 유지 (`Color(0xFF0F1014)`)
   - `accentCoral: Color(0xFFFF8585),` 추가

- [ ] **Step 2: 분석 통과 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze lib/theme/app_colors.dart
```
Expected: No errors

---

## Task 2: BoardApiService — 좋아요한 스토리 API 추가

**Files:**
- Modify: `lib/service/board/board_api_service.dart`

- [ ] **Step 1: `getMyLikedTotal()` 추가**

기존 `getMyLikeTotal()` 메서드 아래에 추가:

```dart
// ── 내가 좋아요한 글 수 ─────────────────────────────────────────────
Future<int> getMyLikedTotal() async {
  final url = ApiUri.resolve('board/post/like/stories/total');
  final headers = await _authHeaders();
  final response = await ApiClient.get(url, headers);

  if (response.statusCode == 200) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final data = body['data'];
    return data is int ? data : 0;
  }

  _logger.e('좋아요한 글 수 조회 실패: ${response.statusCode}');
  return 0;
}
```

- [ ] **Step 2: `getMyLikedPostList()` 추가**

`getMyLikedTotal()` 아래에 추가:

```dart
// ── 내가 좋아요한 글 목록 (무한 스크롤) ────────────────────────────
Future<List<BoardPost>> getMyLikedPostList({int page = 0, int size = 20}) async {
  final url = ApiUri.resolve('board/post/like/stories/list', {
    'page': page.toString(),
    'size': size.toString(),
  });
  final headers = await _authHeaders();
  final response = await ApiClient.get(url, headers);

  if (response.statusCode == 200) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final data = body['data'];
    if (data is List) {
      return data.map((e) => BoardPost.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  _logger.e('좋아요한 글 목록 조회 실패: ${response.statusCode}');
  return [];
}
```

- [ ] **Step 3: 분석 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze lib/service/board/board_api_service.dart
```

---

## Task 3: PostDetailSheet 신규 위젯

**Files:**
- Create: `lib/screens/profile/mypage/post_detail_sheet.dart`

**배경:** `MapCardExpandedContent`는 `MapPost`를 요구한다. `BoardPost`에는 같은 필드가 있으므로, 어댑터 함수로 `BoardPost` → `MapPost` 변환 후 재사용.

- [ ] **Step 1: 파일 생성**

`lib/screens/profile/mypage/post_detail_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/map/bottom_card/map_card_expanded_content.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/map/models/map_post.dart';
import 'package:unimal/theme/app_colors.dart';

/// boardId를 받아 상세+댓글을 DraggableScrollableSheet로 표시.
/// 스트립/목록에서 onTap 시 showPostDetailSheet()로 호출.
Future<void> showPostDetailSheet(BuildContext context, String boardId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PostDetailSheet(boardId: boardId),
  );
}

class _PostDetailSheet extends StatefulWidget {
  final String boardId;
  const _PostDetailSheet({required this.boardId});

  @override
  State<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<_PostDetailSheet> {
  final _boardApi = BoardApiService();
  BoardPost? _detail;
  bool _isLoading = true;
  bool _isLiked = false;
  int? _likeCountOverride;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await _boardApi.getBoardDetail(widget.boardId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _isLiked = detail.isLike;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onLikeTap() async {
    final result = await _boardApi.requestLike(widget.boardId);
    if (result != null && mounted) {
      setState(() {
        _isLiked = result.isLike;
        _likeCountOverride = result.likeCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 핸들
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: colors.primaryStrong,
                          strokeWidth: 2,
                        ),
                      )
                    : _detail == null
                        ? Center(
                            child: Text(
                              '게시글을 불러오지 못했어요',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                color: colors.textTertiary,
                              ),
                            ),
                          )
                        : MapCardExpandedContent(
                            post: _boardPostToMapPost(_detail!),
                            detail: _detail,
                            isLoading: false,
                            isLiked: _isLiked,
                            likeCountOverride: _likeCountOverride,
                            onLikeTap: _onLikeTap,
                            onRefreshDetail: _loadDetail,
                            onEditTap: _detail!.isOwner
                                ? () {
                                    Navigator.pop(context);
                                    Get.toNamed('/edit-board', arguments: _detail);
                                  }
                                : null,
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

MapPost _boardPostToMapPost(BoardPost bp) => MapPost(
      id: bp.boardId,
      nickname: bp.nickname,
      profileImage: bp.profileImage.isNotEmpty ? bp.profileImage : null,
      title: bp.title,
      content: bp.content,
      streetName: bp.streetName,
      latitude: bp.latitude ?? 0.0,
      longitude: bp.longitude ?? 0.0,
      createdAt: bp.createdAt,
      fileInfoList: bp.fileInfoList,
      likeCount: bp.likeCount,
      replyCount: bp.replyCount,
      score: 0.0,
      isOwner: bp.isOwner,
      isLike: bp.isLike,
    );
```

- [ ] **Step 2: 분석 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze lib/screens/profile/mypage/post_detail_sheet.dart
```

---

## Task 4: StoryThumbnailCard 위젯

**Files:**
- Create: `lib/screens/profile/mypage/story_thumbnail_card.dart`

스트립(profile.dart)과 목록(story_list.dart) 공용. 타입: 이미지/텍스트/숏츠 placeholder.

- [ ] **Step 1: 파일 생성**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/theme/app_colors.dart';
import 'package:unimal/utils/display_title.dart';

/// 스트립용 100×128 카드. 이미지 / 텍스트 / 숏츠(placeholder) 분기.
class StoryThumbnailCard extends StatelessWidget {
  final BoardPost post;
  final VoidCallback onTap;

  const StoryThumbnailCard({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasImage = post.fileInfoList.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 128,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: colors.surfaceVariant,
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage ? _ImageCard(post: post, colors: colors) : _TextCard(post: post, colors: colors),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final BoardPost post;
  final AppColors colors;
  const _ImageCard({required this.post, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: post.fileInfoList.first.fileUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: colors.surfaceVariant),
          errorWidget: (_, __, ___) => Container(
            color: colors.primaryWash,
            child: Icon(Icons.image_not_supported_outlined,
                color: colors.primary, size: 24),
          ),
        ),
        // 하단 그라데이션 오버레이
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 10, color: colors.accentCoral),
                const SizedBox(width: 3),
                Text(
                  post.likeCount.toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TextCard extends StatelessWidget {
  final BoardPost post;
  final AppColors colors;
  const _TextCard({required this.post, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_outlined, size: 16, color: colors.primary),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              displayTitle(post.title, post.content),
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Pretendard',
                color: colors.textPrimary,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              Icon(Icons.favorite, size: 10, color: colors.accentCoral),
              const SizedBox(width: 3),
              Text(
                post.likeCount.toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: colors.textTertiary,
                  fontFamily: 'Pretendard',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 분석 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze lib/screens/profile/mypage/story_thumbnail_card.dart
```

---

## Task 5: StoryListScreen 신규 화면

**Files:**
- Create: `lib/screens/profile/mypage/story_list.dart`

- [ ] **Step 1: 파일 생성**

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';
import 'package:unimal/screens/profile/mypage/post_detail_sheet.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/theme/app_colors.dart';
import 'package:unimal/utils/display_title.dart';

enum StoryListMode { myStories, likedStories }

class StoryListScreen extends StatefulWidget {
  const StoryListScreen({super.key});

  @override
  State<StoryListScreen> createState() => _StoryListScreenState();
}

class _StoryListScreenState extends State<StoryListScreen> {
  final _boardApi = BoardApiService();
  late final StoryListMode _mode;

  List<BoardPost> _posts = [];
  int _total = 0;
  bool _isLoading = true;
  String _sortType = 'LATEST'; // myStories 전용

  // likedStories 무한 스크롤
  int _page = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    _mode = args?['mode'] as StoryListMode? ?? StoryListMode.myStories;
    _load();
    if (_mode == StoryListMode.likedStories) {
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreLiked();
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    if (_mode == StoryListMode.myStories) {
      final results = await Future.wait([
        _boardApi.getMyPostTotal(),
        _boardApi.getMyPostList(sortType: _sortType),
      ]);
      if (mounted) {
        setState(() {
          _total = (results[0] as int?) ?? 0;
          _posts = results[1] as List<BoardPost>;
          _isLoading = false;
        });
      }
    } else {
      final results = await Future.wait([
        _boardApi.getMyLikedTotal(),
        _boardApi.getMyLikedPostList(page: 0, size: 20),
      ]);
      if (mounted) {
        setState(() {
          _total = results[0] as int;
          _posts = results[1] as List<BoardPost>;
          _page = 1;
          _hasMore = (_posts.length >= 20);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreLiked() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    final more = await _boardApi.getMyLikedPostList(page: _page, size: 20);
    if (mounted) {
      setState(() {
        _posts.addAll(more);
        _page++;
        _hasMore = more.length >= 20;
        _isLoadingMore = false;
      });
    }
  }

  void _onSortChanged(String sortType) {
    if (_sortType == sortType) return;
    setState(() => _sortType = sortType);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final title = _mode == StoryListMode.myStories ? '내 스토리' : '좋아요한 스토리';
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, colors, title),
            if (_mode == StoryListMode.myStories) _buildSortChips(colors),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: colors.primaryStrong, strokeWidth: 2))
                  : _posts.isEmpty
                      ? _buildEmpty(colors)
                      : ListView.builder(
                          controller: _mode == StoryListMode.likedStories
                              ? _scrollController
                              : null,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _posts.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    color: colors.primaryStrong,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            return _buildListRow(context, colors, _posts[i]);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColors colors, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: colors.textPrimary),
            onPressed: () => Get.back(),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Pretendard',
                color: colors.textPrimary,
              ),
            ),
          ),
          if (!_isLoading)
            Text(
              '총 $_total개',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Pretendard',
                color: colors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortChips(AppColors colors) {
    const chips = [
      ('최신순', 'LATEST'),
      ('좋아요순', 'LIKES'),
      ('댓글순', 'REPLYS'),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final chip in chips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _onSortChanged(chip.$2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _sortType == chip.$2 ? colors.primary : colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    chip.$1,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      color: _sortType == chip.$2 ? Colors.white : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListRow(BuildContext context, AppColors colors, BoardPost post) {
    final hasImage = post.fileInfoList.isNotEmpty;
    return GestureDetector(
      onTap: () => showPostDetailSheet(context, post.boardId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            // 썸네일 84×84
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colors.surfaceVariant,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: post.fileInfoList.first.fileUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: colors.surfaceVariant),
                      errorWidget: (_, __, ___) => Icon(
                        Icons.image_not_supported_outlined,
                        color: colors.primary,
                        size: 24,
                      ),
                    )
                  : Center(
                      child: Icon(Icons.sticky_note_2_outlined,
                          color: colors.primary, size: 28),
                    ),
            ),
            const SizedBox(width: 12),
            // 텍스트 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle(post.title, post.content),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Pretendard',
                      color: colors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 12, color: colors.textTertiary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          post.streetName.isNotEmpty ? post.streetName : '위치 정보 없음',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Pretendard',
                            color: colors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relativeTimeFromString(post.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Pretendard',
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 12, color: colors.accentCoral),
                      const SizedBox(width: 3),
                      Text(
                        post.likeCount.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Pretendard',
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.chat_bubble_outline, size: 12, color: colors.primarySoft),
                      const SizedBox(width: 3),
                      Text(
                        post.replyCount.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Pretendard',
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(AppColors colors) {
    final msg = _mode == StoryListMode.myStories
        ? '아직 스토리가 없어요'
        : '좋아요한 스토리가 없어요';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.place_outlined, size: 48, color: colors.textMuted),
          const SizedBox(height: 16),
          Text(
            msg,
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Pretendard',
              color: colors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 분석 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze lib/screens/profile/mypage/story_list.dart
```

---

## Task 6: app_routes.dart에 /story-list 라우트 추가

**Files:**
- Modify: `lib/screens/navigation/app_routes.dart`

- [ ] **Step 1: import 추가 및 라우트 등록**

`app_routes.dart` 파일 수정:

1. import 추가:
```dart
import 'package:unimal/screens/profile/mypage/story_list.dart';
```

2. `_authRoutes()` 리스트에 추가 (`'/notice-list'` 항목 위):
```dart
GetPage(name: '/story-list', page: () => const StoryListScreen()),
```

- [ ] **Step 2: 분석 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze lib/screens/navigation/app_routes.dart
```

---

## Task 7: profile.dart 전면 재구성

**Files:**
- Modify: `lib/screens/profile/profile.dart`

이 작업은 파일 전체를 새 카드 기반 UI로 대체한다. 유지할 것:
- `_loadUserInfo()` 로직(데이터 로딩)
- `_pickAndUploadProfileImage()`
- `_showEditNicknameSheet()` / `_showEditIntroductionSheet()`
- `refreshProfile()` 공개 메서드
- 로그아웃 다이얼로그

제거할 것:
- 풀스크린 그라데이션 배경
- 상단 기어 아이콘
- 그리드 뷰 (→ 스트립으로 대체)
- 검색/정렬 (→ 목록 화면으로 이전)
- 기존 Stats 카드

추가할 것:
- `_myLikedCount` (좋아요한 글 수)
- 히어로 카드 (그라데이션, 아바타 46, 닉네임, 스토리카운트)
- 내 스토리 썸네일 스트립 (가로 스크롤, StoryThumbnailCard)
- 빈 상태 카드 (스토리 0개 시)
- 메뉴 카드 2행 (내 스토리, 좋아요한 스토리)
- 더보기 카드 (공지, 설정)

- [ ] **Step 1: 파일 전체 교체**

`lib/screens/profile/profile.dart` 전체를 아래 코드로 교체:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:unimal/screens/profile/mypage/mypage.dart';
import 'package:unimal/screens/profile/mypage/post_detail_sheet.dart';
import 'package:unimal/screens/profile/mypage/story_list.dart';
import 'package:unimal/screens/profile/mypage/story_thumbnail_card.dart';
import 'package:unimal/screens/profile/setting/setting.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/user/model/user_info_model.dart';
import 'package:unimal/service/user/user_info_service.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/state/nav_controller.dart';
import 'package:unimal/theme/app_colors.dart';

class ProfileScreens extends StatefulWidget {
  const ProfileScreens({super.key});

  @override
  State<ProfileScreens> createState() => _ProfileScreensState();
}

class _ProfileScreensState extends State<ProfileScreens> {
  final _authState = Get.find<AuthState>();
  final _accountService = AccountService();
  final _userInfoService = UserInfoService();
  final _boardApiService = BoardApiService();
  final _picker = ImagePicker();

  UserInfoModel? _userInfo;
  int _myPostCount = 0;
  int _myLikedCount = 0;
  List<BoardPost> _myPosts = [];
  bool _isLoading = true;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void refreshProfile() => _loadUserInfo();

  Future<void> _loadUserInfo() async {
    final results = await Future.wait([
      _userInfoService.getMemberInfo(_authState.accessToken.value),
      _boardApiService.getMyPostTotal(),
      _boardApiService.getMyLikedTotal(),
      _boardApiService.getMyPostList(sortType: 'LATEST'),
    ]);
    if (mounted) {
      setState(() {
        _userInfo = results[0] as UserInfoModel?;
        _myPostCount = (results[1] as int?) ?? 0;
        _myLikedCount = results[2] as int;
        _myPosts = results[3] as List<BoardPost>;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primaryStrong, strokeWidth: 2))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(colors),
                    const SizedBox(height: 16),
                    _buildStorySection(colors),
                    const SizedBox(height: 16),
                    _buildMenuCard(colors),
                    const SizedBox(height: 12),
                    _buildMoreCard(colors),
                  ],
                ),
              ),
            ),
    );
  }

  // ── 히어로 카드 ─────────────────────────────────────────────────────
  Widget _buildHeroCard(AppColors colors) {
    final displayName = _userInfo?.nickname.isNotEmpty == true
        ? _userInfo!.nickname
        : (_userInfo?.name.isNotEmpty == true ? _userInfo!.name : '사용자');
    final introduction = _userInfo?.introduction.isNotEmpty == true
        ? _userInfo!.introduction
        : '탭하고 소개 글을 입력해 보세요';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primarySoft],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // 아바타 + 카메라 뱃지
          GestureDetector(
            onTap: _isUploadingImage ? null : _pickAndUploadProfileImage,
            child: Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isUploadingImage
                      ? Container(
                          color: Colors.white.withValues(alpha: 0.5),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        )
                      : (_userInfo?.profileImage != null && _userInfo!.profileImage!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: _userInfo!.profileImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildAvatarLetter(displayName, colors),
                            )
                          : _buildAvatarLetter(displayName, colors)),
                ),
                if (!_isUploadingImage)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: colors.primary.withValues(alpha: 0.4), width: 1),
                      ),
                      child: Icon(Icons.add_a_photo_outlined,
                          size: 11, color: colors.primary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // 닉네임 + 소개글
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _showEditNicknameSheet,
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _showEditIntroductionSheet,
                  child: Text(
                    introduction,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontFamily: 'Pretendard',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 스토리 카운트
          Column(
            children: [
              Text(
                _myPostCount.toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: 'Pretendard',
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '스토리',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontFamily: 'Pretendard',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarLetter(String displayName, AppColors colors) {
    final letter = displayName.isNotEmpty ? displayName[0] : 'U';
    return Container(
      color: colors.primaryWash,
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colors.primary,
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }

  // ── 내 스토리 섹션 ──────────────────────────────────────────────────
  Widget _buildStorySection(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '내 스토리',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Pretendard',
                color: colors.textPrimary,
              ),
            ),
            if (_myPosts.isNotEmpty)
              GestureDetector(
                onTap: () => Get.toNamed('/story-list',
                    arguments: {'mode': StoryListMode.myStories}),
                child: Text(
                  '전체보기',
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Pretendard',
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_myPosts.isEmpty)
          _buildEmptyStripCard(colors)
        else
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _myPosts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => StoryThumbnailCard(
                post: _myPosts[i],
                onTap: () => showPostDetailSheet(context, _myPosts[i].boardId),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyStripCard(AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primaryWash,
            ),
            child: Icon(Icons.place_outlined, size: 28, color: colors.primary),
          ),
          const SizedBox(height: 10),
          Text(
            '아직 스토리가 없어요',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Pretendard',
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '발길 닿은 곳의 이야기를 기록해보세요',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Pretendard',
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Get.find<NavController>().requestShareSheet(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.primarySoft],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '첫 스토리 남기기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Pretendard',
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 메뉴 카드 ───────────────────────────────────────────────────────
  Widget _buildMenuCard(AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _buildMenuRow(
            colors: colors,
            icon: Icons.pin_drop_outlined,
            label: '내 스토리',
            count: _myPostCount,
            isFirst: true,
            onTap: () => Get.toNamed('/story-list',
                arguments: {'mode': StoryListMode.myStories}),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: colors.divider),
          _buildMenuRow(
            colors: colors,
            icon: Icons.favorite_border_rounded,
            label: '좋아요한 스토리',
            count: _myLikedCount,
            iconColor: colors.accentCoral,
            onTap: () => Get.toNamed('/story-list',
                arguments: {'mode': StoryListMode.likedStories}),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuRow({
    required AppColors colors,
    required IconData icon,
    required String label,
    required int count,
    required VoidCallback onTap,
    Color? iconColor,
    bool isFirst = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? colors.primary).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor ?? colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  // ── 더보기 카드 ──────────────────────────────────────────────────────
  Widget _buildMoreCard(AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          _buildMoreRow(
            colors: colors,
            icon: Icons.notifications_active_outlined,
            label: '공지사항',
            onTap: () => Get.toNamed('/notice-list'),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: colors.divider),
          _buildMoreRow(
            colors: colors,
            icon: Icons.settings_outlined,
            label: '설정',
            onTap: () => _showSettingsSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreRow({
    required AppColors colors,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: colors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  // ── 프로필 이미지 업로드 ─────────────────────────────────────────────
  Future<void> _pickAndUploadProfileImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _isUploadingImage = true);
    final success = await _userInfoService.uploadProfileImage(
      accessToken: _authState.accessToken.value,
      imageFile: File(picked.path),
    );
    if (success && mounted) await _loadUserInfo();
    if (mounted) setState(() => _isUploadingImage = false);
  }

  // ── 닉네임 수정 ───────────────────────────────────────────────────────
  void _showEditNicknameSheet() {
    final controller = TextEditingController(text: _userInfo?.nickname ?? '');
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool isSaving = false;
        String? errorText;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('닉네임 수정',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Pretendard')),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 20,
                  onChanged: (_) {
                    if (errorText != null)
                      setSheetState(() => errorText = null);
                  },
                  decoration: InputDecoration(
                    hintText: '닉네임을 입력해 주세요',
                    errorText: errorText,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final nickname = controller.text.trim();
                            if (nickname.isEmpty) return;
                            setSheetState(
                                () => isSaving = true);
                            if (nickname != _userInfo?.nickname) {
                              final result =
                                  await _userInfoService.checkNickname(nickname);
                              if (result != 'ok') {
                                setSheetState(() {
                                  isSaving = false;
                                  errorText = result;
                                });
                                return;
                              }
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _updateNickname(nickname);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('저장',
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _updateNickname(String nickname) async {
    final success = await _userInfoService.updateMemberInfo(
      accessToken: _authState.accessToken.value,
      nickname: nickname,
      introduction: _userInfo?.introduction ?? '',
    );
    if (success && mounted) await _loadUserInfo();
  }

  // ── 소개글 수정 ───────────────────────────────────────────────────────
  void _showEditIntroductionSheet() {
    final controller =
        TextEditingController(text: _userInfo?.introduction ?? '');
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('소개글 수정',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Pretendard')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: '나를 소개해 보세요',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _updateIntroduction(controller.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('저장',
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateIntroduction(String introduction) async {
    final success = await _userInfoService.updateMemberInfo(
      accessToken: _authState.accessToken.value,
      nickname: _userInfo?.nickname ?? '',
      introduction: introduction,
    );
    if (success && mounted) await _loadUserInfo();
  }

  // ── 설정 시트 ─────────────────────────────────────────────────────────
  void _showSettingsSheet() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.person_outline, color: colors.textSecondary),
              title: const Text('내 개인정보',
                  style: TextStyle(fontSize: 15, fontFamily: 'Pretendard')),
              onTap: () async {
                Get.back();
                await Get.to(() => const MyPageScreen());
                _loadUserInfo();
              },
            ),
            ListTile(
              leading: Icon(Icons.tune_outlined, color: colors.textSecondary),
              title: const Text('설정',
                  style: TextStyle(fontSize: 15, fontFamily: 'Pretendard')),
              onTap: () {
                Get.back();
                Get.to(() => const SettingScreen());
              },
            ),
            Divider(height: 1, color: colors.divider),
            ListTile(
              leading: Icon(Icons.logout, color: colors.danger),
              title: Text('로그아웃',
                  style: TextStyle(
                      fontSize: 15,
                      color: colors.danger,
                      fontFamily: 'Pretendard')),
              onTap: () {
                Get.back();
                _showLogoutDialog(colors);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(AppColors colors) {
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('로그아웃',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Pretendard')),
      content: const Text('정말 로그아웃 하시겠습니까?',
          style: TextStyle(fontSize: 16, fontFamily: 'Pretendard')),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('취소',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontFamily: 'Pretendard')),
        ),
        TextButton(
          onPressed: () async {
            Get.back();
            await _accountService.logout();
          },
          child: Text('로그아웃',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.danger,
                  fontFamily: 'Pretendard')),
        ),
      ],
    ));
  }
}
```

- [ ] **Step 2: 분석 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze lib/screens/profile/profile.dart
```

---

## Task 8: mypage.dart 하드코딩 색 토큰 치환

**Files:**
- Modify: `lib/screens/profile/mypage/mypage.dart`

- [ ] **Step 1: static const 제거 및 import 추가**

1. `app_colors.dart` import 추가:
```dart
import 'package:unimal/theme/app_colors.dart';
```

2. 클래스 상단의 두 줄 제거:
```dart
static const Color _primary = Color(0xFF5B9FEF);
static const Color _primaryDark = Color(0xFF3578E5);
```

3. `_primary` 사용처 → `AppColors.of(context).primary` (또는 `colors.primary`)로 교체
4. `_primaryDark` 사용처 → `AppColors.of(context).primaryStrong`으로 교체
5. `Color(0xFF4D91FF)` → `AppColors.of(context).primaryStrong`
6. `Color(0xFFE0E0E0)` → `AppColors.of(context).border`

**참고 — 치환 목록 (grep 결과 기반):**

| 원본 | 교체 |
|---|---|
| `_primary` (line 19, 233, 245, 500) | `AppColors.of(context).primary` |
| `_primaryDark` (line 20, 500) | `AppColors.of(context).primaryStrong` |
| `Color(0xFF4D91FF)` (lines 170, 308, 829, 927, 930) | `AppColors.of(context).primaryStrong` |
| `Color(0xFFE0E0E0)` (line 502) | `AppColors.of(context).border` |
| `Color(0xFF3578E5)` (line 893) | `AppColors.of(context).primary` |

**주의:** `mypage.dart`는 여러 build 메서드 / StatefulBuilder를 사용하므로 `AppColors.of(context)`를 각 build 내 지역변수로 받아야 한다. `StatefulBuilder`의 `ctx` 파라미터는 별도 context이므로 `AppColors.of(ctx)` 사용.

- [ ] **Step 2: 분석 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze lib/screens/profile/mypage/mypage.dart
```

---

## Task 9: 전체 분석 + 최종 확인

- [ ] **Step 1: 전체 flutter analyze 실행**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && flutter analyze
```
Expected: 0 errors

- [ ] **Step 2: 변경 파일 목록 확인**

```bash
cd /Users/kwondaeyoung/unimal/app/unimal_flutter && git diff --name-only
```

예상 변경 파일:
- `lib/theme/app_colors.dart`
- `lib/service/board/board_api_service.dart`
- `lib/screens/profile/profile.dart`
- `lib/screens/profile/mypage/mypage.dart`
- `lib/screens/navigation/app_routes.dart`

예상 신규 파일:
- `lib/screens/profile/mypage/post_detail_sheet.dart`
- `lib/screens/profile/mypage/story_thumbnail_card.dart`
- `lib/screens/profile/mypage/story_list.dart`
