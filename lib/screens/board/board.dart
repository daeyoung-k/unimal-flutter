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

class _BoardScreensState extends State<BoardScreens> {
  bool _isSearchFocused = false;
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 0;

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
      final posts = await _boardApiService.getBoardPostList(page: _currentPage);
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
    
    // RefreshIndicator를 사용할 때는 스크롤 이동 불필요 (자동 처리됨)
    // 네비게이션 탭에서 호출될 때만 스크롤 이동
    await _loadPosts();
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
                    : RefreshIndicator(
                        onRefresh: refreshPosts,
                        color: Colors.white,
                        backgroundColor: const Color(0xFF4D91FF),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemCount: _posts.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _posts.length) {
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
