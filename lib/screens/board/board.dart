import 'dart:io';

import 'package:flutter/material.dart';
import 'package:unimal/models/board_post.dart';
import 'package:unimal/repositories/board_repository.dart';
import 'package:unimal/screens/board/widget/card/board_card.dart';
import 'package:unimal/screens/board/widget/board_search.dart';

class BoardScreens extends StatefulWidget {
  const BoardScreens({super.key});

  @override
  State<BoardScreens> createState() => _BoardScreensState();
}

class _BoardScreensState extends State<BoardScreens> {
  bool _isSearchFocused = false;
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;

  final List<BoardPost> _posts = [];
  final BoardRepository _repository = BoardRepository();
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
      final posts = await _repository.getBoardPosts(page: _currentPage);
      setState(() {
        _posts.addAll(posts);
        _isLoading = false;
        _hasMore = posts.isNotEmpty;
      });
    } catch (e) {
      // TODO: 에러 처리
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

  @override
  Widget build(BuildContext context) {
    double topMargin = Platform.isAndroid ? 20 : 0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 235, 235, 235),
        body: SafeArea(
          child: Column(
            children: [
              Padding(padding: EdgeInsets.only(top: topMargin)),
              BoardSearch(
                onFocusChange: (focused) {
                  setState(() {
                    _isSearchFocused = focused;
                  });
                },
              ),
              Padding(padding: EdgeInsets.only(top: 10)),
              if (!_isSearchFocused)
                Expanded(
                  child: _posts.isEmpty && _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _posts.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _posts.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          
                          final post = _posts[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 0, top: 0),
                            child: BoardCard(
                              profileImageUrl: post.profileImageUrl,
                              nickname: post.nickname,
                              location: post.location,
                              imageUrls: post.imageUrls,
                              content: post.content,
                              likeCount: post.likeCount,
                              commentCount: post.commentCount,
                            ),
                          );
                        },
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
