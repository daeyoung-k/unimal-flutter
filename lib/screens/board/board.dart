import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/screens/board/card/board_card.dart';
import 'package:unimal/screens/board/card/board_search.dart';
import 'package:unimal/state/nav_controller.dart';

class BoardScreens extends StatefulWidget {
  const BoardScreens({super.key});

  @override
  State<BoardScreens> createState() => _BoardScreensState();
}

class _BoardScreensState extends State<BoardScreens> {
  bool _isSearchFocused = false;
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String _keyword = '';
  String _sortType = 'LATEST';
  Timer? _debounceTimer;

  final List<BoardPost> _posts = [];
  final BoardApiService _boardApiService = BoardApiService();
  final ScrollController _scrollController = ScrollController();

  static const Color _primary = Color(0xFF7AB3FF);

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final posts = await _boardApiService.getBoardPostList(
        page: _currentPage,
        keyword: _keyword.isNotEmpty ? _keyword : null,
        sortType: _sortType,
      );
      if (!mounted) return;
      setState(() {
        _posts.addAll(posts);
        _isLoading = false;
        _hasMore = posts.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;
    _currentPage++;
    await _loadPosts();
  }

  Future<void> refreshPosts() async {
    setState(() {
      _posts.clear();
      _currentPage = 0;
      _hasMore = true;
    });
    await _loadPosts();
  }

  void _onSearchChanged(String keyword) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _keyword = keyword;
        _posts.clear();
        _currentPage = 0;
        _hasMore = true;
      });
      _loadPosts();
    });
  }

  Widget _buildEmptyState() {
    final bool isSearching = _keyword.isNotEmpty;
    return RefreshIndicator(
      onRefresh: refreshPosts,
      color: _primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pets, size: 52, color: _primary),
                ),
                const SizedBox(height: 24),
                Text(
                  isSearching ? '검색 결과가 없어요' : '아직 올라온 소식이 없어요',
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 18,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isSearching
                      ? '다른 검색어로 다시 찾아보세요 🐾'
                      : '우리 동네 친구들의 소식을\n가장 먼저 공유해보세요 🐾',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                    fontFamily: 'Pretendard',
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double topMargin = Platform.isAndroid ? 20 : 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F7FF),
        floatingActionButton: FloatingActionButton.small(
          heroTag: 'board_fab',
          onPressed: () => Get.find<NavController>().selectedIndex.value = 1,
          backgroundColor: _primary,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(padding: EdgeInsets.only(top: topMargin)),
              // 검색 헤더
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: BoardSearch(
                  onFocusChange: (focused) =>
                      setState(() => _isSearchFocused = focused),
                  onSearchChanged: _onSearchChanged,
                  onSortChanged: (sort) {
                    final map = {'최신순': 'LATEST', '좋아요순': 'LIKES', '댓글순': 'REPLYS'};
                    final sortType = map[sort] ?? 'LATEST';
                    setState(() {
                      _sortType = sortType;
                      _posts.clear();
                      _currentPage = 0;
                      _hasMore = true;
                    });
                    _loadPosts();
                  },
                ),
              ),
              const SizedBox(height: 12),
              // 게시글 리스트
              if (!_isSearchFocused)
                Expanded(
                  child: _posts.isEmpty && _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: _primary),
                        )
                      : _posts.isEmpty && !_isLoading
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: refreshPosts,
                              color: _primary,
                              child: ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                                itemCount: _posts.length + (_hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _posts.length) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) _loadMorePosts();
                                    });
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(
                                            color: _primary),
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: BoardCard(boardPost: _posts[index]),
                                  );
                                },
                              ),
                            ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
