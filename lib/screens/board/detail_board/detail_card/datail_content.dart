import 'package:flutter/material.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/utils/time_utils.dart';

class DetailContent extends StatefulWidget {
  final String? title;
  final String content;
  final bool? isLike;
  final String? likeCount;
  final String? replyCount;
  final String? boardId;
  final String? createdAt;

  const DetailContent({
    super.key,
    this.title = '',
    required this.content,
    this.isLike,
    this.likeCount,
    this.replyCount,
    this.boardId,
    this.createdAt,
  });

  @override
  State<DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<DetailContent> {
  final BoardApiService _boardApiService = BoardApiService();
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLike ?? false;
    _likeCount = int.tryParse(widget.likeCount ?? "0") ?? 0;
  }

  @override
  void didUpdateWidget(DetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLike != widget.isLike) {
      setState(() => _isLiked = widget.isLike ?? false);
    }
    if (oldWidget.likeCount != widget.likeCount) {
      setState(() => _likeCount = int.tryParse(widget.likeCount ?? "0") ?? 0);
    }
  }

  Future<void> _toggleLike() async {
    if (widget.boardId == null || widget.boardId!.isEmpty) {
      setState(() => _isLiked = !_isLiked);
      return;
    }
    if (_isLoading) return;

    final previousIsLiked = _isLiked;
    final previousLikeCount = _likeCount;

    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
      _isLoading = true;
    });

    try {
      final likeInfo = await _boardApiService.requestLike(widget.boardId!);
      if (likeInfo != null && mounted) {
        setState(() {
          _isLiked = likeInfo.isLike;
          if (likeInfo.likeCount != null) _likeCount = likeInfo.likeCount!;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = previousIsLiked;
          _likeCount = previousLikeCount;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null && widget.title!.isNotEmpty) ...[
            Text(
              widget.title!,
              style: const TextStyle(
                fontSize: 20,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            widget.content.isEmpty ? '내용이 없습니다.' : widget.content,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              color: Color(0xFF4B5563),
              height: 1.65,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF3F4F6), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              // 좋아요 버튼
              GestureDetector(
                onTap: _toggleLike,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        key: ValueKey(_isLiked),
                        color: _isLiked ? const Color(0xFFFF6B6B) : const Color(0xFF9CA3AF),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Text(
                        _likeCount.toString(),
                        key: ValueKey(_likeCount),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _isLiked ? const Color(0xFFFF6B6B) : const Color(0xFF9CA3AF),
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              // 댓글 수
              Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 6),
                  Text(
                    widget.replyCount ?? '0',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // 시간
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(
                    TimeUtils.getRelativeTime(widget.createdAt ?? ''),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
