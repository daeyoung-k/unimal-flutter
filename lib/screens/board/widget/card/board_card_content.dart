
import 'package:flutter/material.dart';

class BoardCardContent extends StatefulWidget {
  final String content;
  final String? likeCount;
  final String? commentCount;
  final int maxLine;
  final VoidCallback? onTap;
  
  const BoardCardContent({
    super.key, 
    required this.content, 
    this.likeCount = "0", 
    this.commentCount = "0", 
    required this.maxLine, 
    this.onTap
  });

  @override
  State<BoardCardContent> createState() => _BoardCardContentState();
}

class _BoardCardContentState extends State<BoardCardContent> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
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
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            padding: const EdgeInsets.all(14),
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
                // 액션 버튼들
                Row(
                  children: [
                    // 좋아요 버튼
                    GestureDetector(
                      onTap: _toggleLike,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),                      
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                _isLiked ? Icons.favorite : Icons.favorite_border,
                                key: ValueKey(_isLiked),
                                color: _isLiked ? Colors.red : Colors.grey[600],
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.likeCount!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _isLiked ? Colors.red : Colors.grey[600],
                                fontFamily: 'Pretendard',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 15), 
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey[600],
                          size: 18,
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
                    // 공유 버튼
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.share_outlined,
                        color: Colors.grey[600],
                        size: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 콘텐츠 텍스트
                Text(
                  widget.content,
                  maxLines: widget.maxLine,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF2C3E50),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
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
                      '방금 전',
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
          ),
        ),
      ),
    );
  }
}