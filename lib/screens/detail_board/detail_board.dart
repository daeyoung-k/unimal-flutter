import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/models/board_post.dart';
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
    // Get.parameters로 URL 파라미터에서 id 받기
    final String? id = Get.parameters['id'];
    
    final Map<String, dynamic> args = (Get.arguments as Map<String, dynamic>?) ?? {};

    BoardPost? boardPost = (args['boardPost'] as BoardPost?);

    if (boardPost == null) {
      //TODO: API 연동 시 id를 사용하여 데이터 조회
      // 예: await BoardApiService().getBoardDetail(id ?? '');
      // id가 있으면 해당 게시물을 조회하고, 없으면 기본값 사용
      boardPost = BoardPost(
        boardId: id != null ? int.tryParse(id) ?? 0 : 0,
        profileImageUrl: '',
        nickname: '',
        location: '',
        imageUrls: [],
        content: '',
        likeCount: '0',
        commentCount: '0',
      );
    }

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
                      DetailBoardCard(boardPost: boardPost),
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



