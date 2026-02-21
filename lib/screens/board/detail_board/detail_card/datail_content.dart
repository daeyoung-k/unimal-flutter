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
    // widget.isLike 값을 초기값으로 설정
    _isLiked = widget.isLike ?? false;
    // widget.likeCount 값을 초기값으로 설정
    _likeCount = int.tryParse(widget.likeCount ?? "0") ?? 0;
  }

  @override
  void didUpdateWidget(DetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // widget.isLike 값이 변경되면 _isLiked도 업데이트
    if (oldWidget.isLike != widget.isLike) {
      setState(() {
        _isLiked = widget.isLike ?? false;
      });
    }
    // widget.likeCount 값이 변경되면 _likeCount도 업데이트
    if (oldWidget.likeCount != widget.likeCount) {
      setState(() {
        _likeCount = int.tryParse(widget.likeCount ?? "0") ?? 0;
      });
    }
  }

  Future<void> _toggleLike() async {
    // boardId가 없으면 로컬 상태만 변경
    if (widget.boardId == null || widget.boardId!.isEmpty) {
      setState(() {
        _isLiked = !_isLiked;
      });
      return;
    }

    // 이미 로딩 중이면 중복 요청 방지
    if (_isLoading) return;

    // 즉시 UI 업데이트 (optimistic update)
    final previousIsLiked = _isLiked;
    final previousLikeCount = _likeCount;
    
    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
      _isLoading = true;
    });

    try {
      // requestLike 호출하여 서버에서 최신 좋아요 상태 가져오기
      final likeInfo = await _boardApiService.requestLike(widget.boardId!);
      
      // 서버 응답으로 받은 isLike 값으로 UI 상태 업데이트
      if (likeInfo != null && mounted) {
        setState(() {
          // 서버에서 받아온 isLike 값으로 좋아요 아이콘 상태 반영
          _isLiked = likeInfo.isLike;
          // 서버에서 받아온 likeCount 값으로 좋아요 개수 반영
          if (likeInfo.likeCount != null) {
            _likeCount = likeInfo.likeCount!;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      // 에러 발생 시 이전 상태로 롤백
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          // 제목 표시
          if (widget.title != null && widget.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                widget.title!,
                style: const TextStyle(
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            
          // 콘텐츠 텍스트
          Text(
            widget.content.isEmpty ? '내용이 없습니다.' : widget.content,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              color: Color(0xFF2C3E50),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
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
                        key: ValueKey('${_isLiked ? 'filled' : 'outlined'}_${_isLiked ? 'red' : 'grey'}'),
                        color: _isLiked ? Colors.red : Colors.grey[600],
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Text(
                        _likeCount.toString(),
                        key: ValueKey(_likeCount),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _isLiked ? Colors.red : Colors.grey[600],
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.access_time,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                TimeUtils.getRelativeTime(widget.createdAt ?? ''),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontFamily: 'Pretendard',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}