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
  final bool isLiked;
  final int? likeCountOverride;
  final VoidCallback? onLikeTap;

  /// 댓글 작성/수정/삭제 후 호출 — 부모가 detail을 재로딩한다.
  final Future<void> Function()? onRefreshDetail;

  const MapCardExpandedContent({
    super.key,
    required this.post,
    required this.detail,
    required this.isLoading,
    this.isLiked = false,
    this.likeCountOverride,
    this.onLikeTap,
    this.onRefreshDetail,
  });

  @override
  State<MapCardExpandedContent> createState() => _MapCardExpandedContentState();
}

class _MapCardExpandedContentState extends State<MapCardExpandedContent> {
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  final _editController = TextEditingController();
  bool _isSending = false;
  String? _editingReplyId; // null이면 수정 모드 아님
  bool _isSavingEdit = false;
  // 답글 작성 대상. null이면 일반 댓글 모드, 값 있으면 그 댓글에 대한 답글 모드.
  String? _replyToId;
  String? _replyToNickname;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _setReplyTo(ReplyInfo parent) {
    setState(() {
      _replyToId = parent.id;
      _replyToNickname = parent.nickname;
    });
    _commentFocus.requestFocus();
  }

  void _clearReplyTo() {
    setState(() {
      _replyToId = null;
      _replyToNickname = null;
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      final ok = await BoardApiService().createReply(
        widget.post.id,
        text,
        replyId: _replyToId,
      );
      if (ok && mounted) {
        _commentController.clear();
        _replyToId = null;
        _replyToNickname = null;
        await widget.onRefreshDetail?.call();
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startEditReply(ReplyInfo reply) {
    setState(() {
      _editingReplyId = reply.id;
      _editController.text = reply.comment;
    });
  }

  void _cancelEditReply() {
    setState(() {
      _editingReplyId = null;
      _editController.clear();
    });
  }

  Future<void> _saveEditReply(ReplyInfo reply) async {
    final text = _editController.text.trim();
    if (text.isEmpty || _isSavingEdit) return;
    setState(() => _isSavingEdit = true);
    try {
      final ok = await BoardApiService()
          .updateReply(widget.post.id, reply.id, text);
      if (ok && mounted) {
        _editingReplyId = null;
        _editController.clear();
        await widget.onRefreshDetail?.call();
      }
    } finally {
      if (mounted) setState(() => _isSavingEdit = false);
    }
  }

  Future<void> _confirmDeleteReply(ReplyInfo reply) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 삭제', style: TextStyle(fontFamily: 'Pretendard')),
        content: const Text('댓글을 삭제할까요? 삭제 후에는 복구할 수 없어요.',
            style: TextStyle(fontFamily: 'Pretendard')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(fontFamily: 'Pretendard')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제',
                style: TextStyle(
                    fontFamily: 'Pretendard', color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await BoardApiService().deleteReply(widget.post.id, reply.id);
    if (ok && mounted) {
      await widget.onRefreshDetail?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 스크롤 가능 영역 — 빈 공간 탭 시 키보드 내리기
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPostInfo(),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFE5E7EB), height: 1),
                  const SizedBox(height: 12),
                  _buildComments(),
                ],
              ),
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
        // 헤더: [아바타] (닉네임 / 위치) (우측: 날짜)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(imageUrl: post.profileImage, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.nickname,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.streetName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(Icons.location_on_outlined,
                              size: 13, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            post.streetName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                              color: Color(0xFF6B7280),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              relativeTimeFromString(post.createdAt),
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Pretendard',
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        // 타이틀
        const SizedBox(height: 14),
        Text(
          post.title.isNotEmpty ? post.title : '제목 없음',
          style: const TextStyle(
            fontSize: 17,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        // 내용
        if (post.content.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            post.content,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'Pretendard',
              color: Color(0xFF4B5563),
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onLikeTap,
              child: Row(
                children: [
                  Icon(
                    widget.isLiked ? Icons.favorite : Icons.favorite_outline,
                    size: 16,
                    color: widget.isLiked
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.likeCountOverride ?? post.likeCount}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Pretendard',
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
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
    final active = replies.where((r) => !r.isDel).toList();
    final topLevel = active.where((r) => !r.reReplyYn).toList();
    if (active.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            '아직 댓글이 없어요',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Pretendard',
              color: Color(0xFF9E9E9E),
            ),
          ),
        ),
      );
    }
    // 부모 댓글 아래에 같은 replyId를 가진 대댓글을 들여쓰기로 이어 붙임.
    final items = <Widget>[];
    for (final parent in topLevel) {
      items.add(_buildReplyItem(parent));
      final nested = active.where(
        (r) => r.reReplyYn && r.replyId == parent.id,
      );
      for (final child in nested) {
        items.add(_buildReplyItem(child, isNested: true));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '댓글 ${active.length}',
          style: const TextStyle(
            fontSize: 13,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
            color: Color(0xFF9E9E9E),
          ),
        ),
        const SizedBox(height: 10),
        ...items,
      ],
    );
  }

  Widget _buildReplyItem(ReplyInfo reply, {bool isNested = false}) {
    final isEditing = _editingReplyId == reply.id;
    // 대댓글이면 아바타(28) + 좌측 간격(10) 만큼 들여써서 부모와 시각적으로 구분.
    return Padding(
      padding: EdgeInsets.only(bottom: 14, left: isNested ? 38 : 0),
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
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              reply.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
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
                    ),
                    if (reply.isOwner && !isEditing)
                      _buildReplyMenu(reply),
                  ],
                ),
                const SizedBox(height: 3),
                if (isEditing) _buildEditField(reply) else _buildReplyBody(reply),
                // 답글 트리거 — 부모 댓글에만 표시 (대댓글은 depth 1만 지원).
                if (!isNested && !isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: () => _setReplyTo(reply),
                      behavior: HitTestBehavior.opaque,
                      child: const Text(
                        '답글 달기',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBody(ReplyInfo reply) {
    return Text(
      reply.comment,
      style: const TextStyle(
        fontSize: 13,
        fontFamily: 'Pretendard',
        color: Color(0xFF4B5563),
        height: 1.4,
      ),
    );
  }

  Widget _buildReplyMenu(ReplyInfo reply) {
    return SizedBox(
      width: 28,
      height: 28,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: const Icon(Icons.more_horiz, color: Color(0xFF9CA3AF)),
        onSelected: (value) {
          if (value == 'edit') _startEditReply(reply);
          if (value == 'delete') _confirmDeleteReply(reply);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'edit',
            child: Text('수정', style: TextStyle(fontFamily: 'Pretendard', fontSize: 13)),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text('삭제',
                style: TextStyle(
                    fontFamily: 'Pretendard', fontSize: 13, color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(ReplyInfo reply) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _editController,
            autofocus: true,
            maxLines: null,
            style: const TextStyle(
              fontSize: 13,
              fontFamily: 'Pretendard',
              color: Color(0xFF1A1A2E),
              height: 1.4,
            ),
            decoration: const InputDecoration.collapsed(hintText: '댓글 수정'),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isSavingEdit ? null : _cancelEditReply,
              style: TextButton.styleFrom(
                minimumSize: const Size(40, 28),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('취소',
                  style: TextStyle(
                      fontFamily: 'Pretendard', fontSize: 12, color: Color(0xFF6B7280))),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: _isSavingEdit ? null : () => _saveEditReply(reply),
              style: TextButton.styleFrom(
                minimumSize: const Size(40, 28),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: _isSavingEdit
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF4D91FF)),
                    )
                  : const Text('저장',
                      style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: Color(0xFF4D91FF),
                          fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final isReplyMode = _replyToId != null;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + safeBottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 답글 모드 인디케이터 — 부모 댓글에 답글 작성 중임을 표시 + 취소(X).
          if (isReplyMode)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF6FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '@${_replyToNickname ?? ''} 에게 답글',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4D91FF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearReplyTo,
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const _Avatar(imageUrl: null, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocus,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'Pretendard',
                      color: Color(0xFF1A1A2E),
                    ),
                    decoration: InputDecoration.collapsed(
                      hintText: isReplyMode ? '답글을 입력하세요...' : '나도 한 마디...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9E9E9E),
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
                    : const Icon(Icons.send_rounded,
                        color: Color(0xFF4D91FF), size: 22),
              ),
            ],
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
        color: Color(0xFFF5F5F5),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
          : Icon(Icons.person_outline, size: size * 0.6, color: const Color(0xFFBBBBBB)),
    );
  }
}
