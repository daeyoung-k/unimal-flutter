import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/screens/board/card/board_card_content.dart';
import 'package:unimal/screens/board/card/board_card_image.dart';
import 'package:unimal/screens/board/card/board_card_profile.dart';

class BoardCard extends StatefulWidget {
  final BoardPost boardPost;

  const BoardCard({
    super.key, 
    required this.boardPost,
  });

  @override
  State<BoardCard> createState() => _BoardCardState();

}

class _BoardCardState extends State<BoardCard>
    with TickerProviderStateMixin {

  final BoardApiService _boardApiService = BoardApiService();
  late AnimationController _cardAnimationController;
  late Animation<double> _cardFadeAnimation;
  late Animation<double> _cardScaleAnimation;
  late Animation<Offset> _cardSlideAnimation;

  Future<void> _confirmDelete() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '게시글 삭제',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: const Text(
          '게시글을 삭제하면 복구할 수 없어요.\n정말 삭제할까요?',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            color: Color(0xFF666666),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              '취소',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              '삭제',
              style: TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _boardApiService.deleteBoard(widget.boardPost.boardId);
    if (success) {
      Get.offAllNamed('/board');
    } else {
      Get.dialog(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('삭제 실패', style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 16)),
          content: const Text('게시글 삭제에 실패했습니다.\n잠시 후 다시 시도해주세요.', style: TextStyle(fontFamily: 'Pretendard', fontSize: 14, color: Color(0xFF666666))),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('확인', style: TextStyle(fontFamily: 'Pretendard', color: Color(0xFF4D91FF), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }
  }

  void _goToDetail() {
    // Get.toNamed를 사용하여 parameters에 id를 명시적으로 전달
    // 이렇게 하면 이전 파라미터가 초기화되고 새로운 id로 설정됨
    Get.toNamed(
      '/detail-board',
      parameters: {
        'id': widget.boardPost.boardId.toString(),
      },
      arguments: {
        'boardPost': widget.boardPost,
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _cardFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
    ));
    
    _cardScaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));
    
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));
    
    _cardAnimationController.forward();
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    super.dispose();
  }
        
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return FadeTransition(
      opacity: _cardFadeAnimation,
      child: ScaleTransition(
        scale: _cardScaleAnimation,
        child: SlideTransition(
          position: _cardSlideAnimation,
          child: Container(
            width: screenWidth * 0.96,
            margin: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                // 프로필 영역
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _goToDetail,
                  child: BoardCardProfile(
                    screenHeight: screenHeight,
                    profileImageUrl: widget.boardPost.profileImage,
                    nickname: widget.boardPost.nickname,
                    location: widget.boardPost.streetName,
                    isOwner: widget.boardPost.isOwner,
                    onEdit: () {
                      Get.toNamed('/edit-board', arguments: widget.boardPost);
                    },
                    onDelete: _confirmDelete,
                  ),
                ),
                // 이미지 영역 (있는 경우에만)
                if (widget.boardPost.fileInfoList.isNotEmpty) 
                  BoardCardImage(
                    screenHeight: screenHeight, 
                    imageUrls: widget.boardPost.fileInfoList.map((e) => e.fileUrl).toList(),
                  ),
                // 콘텐츠 영역
                BoardCardContent(
                  title: widget.boardPost.title,
                  content: widget.boardPost.content,
                  isLike: widget.boardPost.isLike,
                  likeCount: widget.boardPost.likeCount.toString(),
                  commentCount: widget.boardPost.replyCount.toString(),
                  maxLine: widget.boardPost.fileInfoList.isNotEmpty ? 2 : 5,
                  onTap: _goToDetail,
                  boardId: widget.boardPost.boardId,
                  createdAt: widget.boardPost.createdAt,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}