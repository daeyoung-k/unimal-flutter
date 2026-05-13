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
            Text(
              '${post.likeCount}',
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Pretendard',
                color: Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.chat_bubble_outline, size: 15, color: Color(0xFF4D91FF)),
            const SizedBox(width: 4),
            Text(
              '${post.replyCount}',
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'Pretendard',
                color: Color(0xFF9E9E9E),
              ),
            ),
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
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Pretendard',
              color: Color(0xFF555555),
            ),
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
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'Pretendard',
                        color: Color(0xFF6B7280),
                      ),
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
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'Pretendard',
                  color: Colors.white,
                ),
                decoration: const InputDecoration.collapsed(
                  hintText: '나도 한 마디...',
                  hintStyle: TextStyle(
                    color: Color(0xFF555555),
                    fontFamily: 'Pretendard',
                  ),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF4D91FF),
                    ),
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
