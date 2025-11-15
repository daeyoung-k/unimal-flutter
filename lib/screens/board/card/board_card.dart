import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/models/board_post.dart';
import 'package:unimal/screens/detail_board/detail_board.dart';
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
  
  late AnimationController _cardAnimationController;
  late Animation<double> _cardFadeAnimation;
  late Animation<double> _cardScaleAnimation;
  late Animation<Offset> _cardSlideAnimation;

  void _goToDetail() {
    Get.to(() => const DetailBoardScreen(), arguments: {
      'boardPost': widget.boardPost,
    });
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
                    profileImageUrl: widget.boardPost.profileImageUrl, 
                    nickname: widget.boardPost.nickname, 
                    location: widget.boardPost.location
                  ),
                ),
                // 이미지 영역 (있는 경우에만)
                if (widget.boardPost.imageUrls.isNotEmpty) 
                  BoardCardImage(
                    screenHeight: screenHeight, 
                    imageUrls: widget.boardPost.imageUrls,
                  ),
                // 콘텐츠 영역
                BoardCardContent(
                  title: widget.boardPost.title,
                  content: widget.boardPost.content,
                  likeCount: widget.boardPost.likeCount,
                  commentCount: widget.boardPost.commentCount,
                  maxLine: widget.boardPost.imageUrls.isNotEmpty ? 2 : 5,
                  onTap: _goToDetail,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}