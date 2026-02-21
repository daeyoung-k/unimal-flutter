import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/screens/board/card/board_card.dart';
import 'package:unimal/screens/board/card/board_search.dart';

class BoardScreens extends StatefulWidget {
  const BoardScreens({super.key});

  @override
  State<BoardScreens> createState() => _BoardScreensState();
  
  // GlobalKey를 통해 State에 접근하기 위한 static 메서드
  static _BoardScreensState? of(BuildContext? context) {
    if (context == null) return null;
    final state = context.findAncestorStateOfType<_BoardScreensState>();
    return state;
  }
}

// 정렬 UI 레이블 → API 값 매핑
const Map<String, String> _sortTypeMap = {
  '최신순': 'LATEST',
  '좋아요순': 'LIKES',
  '댓글순': 'REPLYS',
};

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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final posts = await _boardApiService.getBoardPostList(
        page: _currentPage,
        keyword: _keyword.isNotEmpty ? _keyword : null,
        sortType: _sortType,
      );
      setState(() {
        _posts.addAll(posts);
        _isLoading = false;
        _hasMore = posts.isNotEmpty;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;
    
    _currentPage++;
    await _loadPosts();
  }

  // 새로고침 메서드: 리스트 초기화 후 첫 페이지부터 다시 로드
  Future<void> refreshPosts() async {
    setState(() {
      _posts.clear();
      _currentPage = 0;
      _hasMore = true;
    });
    await _loadPosts();
  }

  Widget _buildEmptyState() {
    final bool isSearching = _keyword.isNotEmpty;
    return RefreshIndicator(
      onRefresh: refreshPosts,
      color: Colors.white,
      backgroundColor: const Color(0xFF4D91FF),
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
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pets,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isSearching ? '검색 결과가 없어요' : '아직 올라온 소식이 없어요',
                  style: const TextStyle(
                    color: Colors.white,
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
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
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

  void _onSearchChanged(String keyword) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _keyword = keyword;
        _posts.clear();
        _currentPage = 0;
        _hasMore = true;
      });
      _loadPosts();
    });
  }

  void _onSortChanged(String sortLabel) {
    final sortType = _sortTypeMap[sortLabel] ?? 'LATEST';
    if (_sortType == sortType) return;
    setState(() {
      _sortType = sortType;
      _posts.clear();
      _currentPage = 0;
      _hasMore = true;
    });
    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    double topMargin = Platform.isAndroid ? 20 : 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF4D91FF),
        body: SafeArea(
          child: Column(
            children: [
              Padding(padding: EdgeInsets.only(top: topMargin)),
              // 검색 위젯을 흰색 카드로 감싸기
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: BoardSearch(
                    onFocusChange: (focused) {
                      setState(() {
                        _isSearchFocused = focused;
                      });
                    },
                    onSearchChanged: _onSearchChanged,
                    onSortChanged: _onSortChanged,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_isSearchFocused)
                Expanded(
                  child: _posts.isEmpty && _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : _posts.isEmpty && !_isLoading
                      ? _buildEmptyState()
                      : RefreshIndicator(
                        onRefresh: refreshPosts,
                        color: Colors.white,
                        backgroundColor: const Color(0xFF4D91FF),
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemCount: _posts.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _posts.length) {
                              // 스피너가 화면에 렌더되는 순간 다음 페이지 로드 트리거
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) { if (mounted) _loadMorePosts(); },
                              );
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              );
                            }
                            
                            final post = _posts[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: BoardCard(boardPost: post),
                              ),
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
