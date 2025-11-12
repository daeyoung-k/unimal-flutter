import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/detail_board/detail_board.dart';
import 'package:unimal/screens/board/card/board_card_content.dart';
import 'package:unimal/screens/board/card/board_card_image.dart';
import 'package:unimal/screens/board/card/board_card_profile.dart';

class BoardCard extends StatefulWidget {
  
  // backend 데이터 받아오는 영역
  final int boardId;
  final String profileImageUrl;
  final String nickname;
  final String location;
  final List<String> imageUrls;
  final String? title;
  final String content;
  final String likeCount;
  final String commentCount;

  const BoardCard({
    super.key, 
    required this.boardId,
    required this.profileImageUrl,
    required this.nickname,
    required this.location,
    required this.imageUrls, 
    this.title = '',
    required this.content, 
    required this.likeCount, 
    required this.commentCount
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
      'boardId': widget.boardId,
      'profileImageUrl': widget.profileImageUrl,
      'author': widget.nickname,
      'streetName': widget.location,
      'imageUrls': widget.imageUrls,
      'content': widget.content,
      'likeCount': widget.likeCount,
      'commentCount': widget.commentCount,
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
                    profileImageUrl: widget.profileImageUrl, 
                    nickname: widget.nickname, 
                    location: widget.location
                  ),
                ),
                // 이미지 영역 (있는 경우에만)
                if (widget.imageUrls.isNotEmpty) 
                  BoardCardImage(
                    screenHeight: screenHeight, 
                    imageUrls: widget.imageUrls,
                  ),
                // 콘텐츠 영역
                BoardCardContent(
                  content: widget.content,
                  likeCount: widget.likeCount,
                  commentCount: widget.commentCount,
                  maxLine: widget.imageUrls.isNotEmpty ? 2 : 5,
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