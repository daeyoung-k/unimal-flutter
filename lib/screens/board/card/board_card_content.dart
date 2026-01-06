
import 'package:flutter/material.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/utils/time_utils.dart';

class BoardCardContent extends StatefulWidget {
  final String? title;
  final String content;
  final bool? isLike;
  final String? likeCount;
  final String? commentCount;
  final int maxLine;
  final VoidCallback? onTap;
  final String? boardId;
  final String? createdAt;
  
  const BoardCardContent({
    super.key, 
    required this.maxLine, 
    required this.content, 
    this.title = '',
    this.isLike,
    this.likeCount = "0", 
    this.commentCount = "0", 
    this.onTap,
    this.boardId,
    this.createdAt,
  });

  @override
  State<BoardCardContent> createState() => _BoardCardContentState();
}

class _BoardCardContentState extends State<BoardCardContent> 
  with SingleTickerProviderStateMixin {
  
  final BoardApiService _boardApiService = BoardApiService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
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
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void didUpdateWidget(BoardCardContent oldWidget) {
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
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
                  widget.content,
                  maxLines: widget.maxLine,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF2C3E50),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                // 시간 표시와 액션 버튼들
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
                                fontWeight: FontWeight.w500,
                                color: _isLiked ? Colors.red : Colors.grey[600],
                                fontFamily: 'Pretendard',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15), 
                    // 댓글 버튼
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.commentCount!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ],
                    ),    
                    const Spacer(),
                    // 시간 표시
                    Row(
                      children: [
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}