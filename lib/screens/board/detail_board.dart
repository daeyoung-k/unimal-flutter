import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/board/widget/detailcard/detail_board_card.dart';

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
                      _CommentSection(
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
            // 댓글 입력 영역
            _CommentInput(
              controller: _commentController,
              onSend: _addComment,
            ),
          ],
        ),
      ),
    );
  }
}

// 댓글 섹션 위젯
class _CommentSection extends StatelessWidget {
  final List<Map<String, dynamic>> comments;
  final Function(int) onDelete;

  const _CommentSection({
    required this.comments,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
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
        child: Center(
          child: Text(
            '아직 댓글이 없습니다.\n첫 번째 댓글을 남겨보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  '댓글 ${comments.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...comments.map((comment) => _CommentItem(
                comment: comment,
                onDelete: () => onDelete(comment['id'] as int),
              )),
        ],
      ),
    );
  }
}

// 댓글 아이템 위젯
class _CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback onDelete;

  const _CommentItem({
    required this.comment,
    required this.onDelete,
  });

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[200],
            backgroundImage: NetworkImage(comment['profileImageUrl'] as String),
            onBackgroundImageError: (e, s) {},
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment['author'] as String,
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDateTime(comment['createdAt'] as DateTime),
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Pretendard',
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment['content'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF2C3E50),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[400]),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text(
                      '삭제',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onDelete();
                    },
                  ),
                ),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// 댓글 입력 위젯
class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _CommentInput({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '댓글을 입력하세요...',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontFamily: 'Pretendard',
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4D91FF),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: onSend,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


