import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/detail_board/comment/comment_input.dart';
import 'package:unimal/screens/detail_board/comment/comment_section.dart';
import 'package:unimal/screens/detail_board/detail_card/detail_board_card.dart';

class DetailBoardScreen extends StatefulWidget {
  const DetailBoardScreen({super.key});

  @override
  State<DetailBoardScreen> createState() => _DetailBoardScreenState();
}

class _DetailBoardScreenState extends State<DetailBoardScreen> {
  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, dynamic>> _comments = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addComment() {
    if (_commentController.text.trim().isEmpty) return;

    // 키보드 내리기
    FocusScope.of(context).unfocus();

    setState(() {
      _comments.add({
        'id': DateTime.now().millisecondsSinceEpoch,
        'author': '나',
        'content': _commentController.text.trim(),
        'profileImageUrl': 'https://via.placeholder.com/150',
        'createdAt': DateTime.now(),
      });
      _commentController.clear();
    });

    // 댓글 추가 후 스크롤을 맨 아래로
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args = (Get.arguments as Map<String, dynamic>?) ?? {};

    // TODO: API 연동 시 댓글 조회에 사용
    // ignore: unused_local_variable
    final int boardId = (args['boardId'] as int?) ?? 0;
    final String content = (args['content'] as String?)?.trim() ?? '';
    final List<dynamic> imageUrlsDynamic = (args['imageUrls'] as List<dynamic>?) ?? const [];
    final List<String> imageUrls = imageUrlsDynamic.map((e) => e.toString()).toList();
    final String streetName = (args['streetName'] as String?) ?? '';
    final String author = (args['author'] as String?) ?? '익명';
    final String likeCount = (args['likeCount'] as String?) ?? '0';
    final String commentCount = (args['commentCount'] as String?) ?? '0';
    final String profileImageUrl = (args['profileImageUrl'] as String?)?.trim().isNotEmpty == true
        ? (args['profileImageUrl'] as String)
        : 'https://via.placeholder.com/150';

    return Scaffold(
      backgroundColor: const Color(0xFF4D91FF),
      // 키보드가 올라올 때 레이아웃 자동 조정
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
                  child: Column(
                    children: [
                      DetailBoardCard(
                        profileImageUrl: profileImageUrl,
                        nickname: author,
                        location: streetName.isNotEmpty ? streetName : '위치 정보 없음',
                        imageUrls: imageUrls,
                        content: content,
                        likeCount: likeCount,
                        commentCount: commentCount,
                      ),
                      const SizedBox(height: 10),
                      // 댓글 영역
                      CommentSection(
                        comments: _comments,
                        onDelete: (commentId) {
                          setState(() {
                            _comments.removeWhere((comment) => comment['id'] == commentId);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 댓글 입력 영역 (키보드가 올라올 때 함께 올라감)
            CommentInput(
              controller: _commentController,
              onSend: _addComment,
            ),
          ],
        ),
      ),
    );
  }
}



