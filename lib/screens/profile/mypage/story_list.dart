import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  String _sortType = 'LATEST';

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
                      child: CircularProgressIndicator(
                          color: colors.primaryStrong, strokeWidth: 2))
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
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: colors.textPrimary),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _sortType == chip.$2
                        ? colors.primary
                        : colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    chip.$1,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      color: _sortType == chip.$2
                          ? Colors.white
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListRow(
      BuildContext context, AppColors colors, BoardPost post) {
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
                      placeholder: (_, __) =>
                          Container(color: colors.surfaceVariant),
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
                      Icon(Icons.location_on_outlined,
                          size: 12, color: colors.textTertiary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          post.streetName.isNotEmpty
                              ? post.streetName
                              : '위치 정보 없음',
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
                      Icon(Icons.chat_bubble_outline,
                          size: 12, color: colors.primarySoft),
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
