import 'package:flutter/material.dart';
import 'package:unimal/widget/board/card/board_card_content.dart';
import 'package:unimal/widget/board/card/board_card_image.dart';
import 'package:unimal/widget/board/card/board_card_profile.dart';

class BoardCard extends StatefulWidget {
  
  // backend 데이터 받아오는 영역
  final String profileImageUrl;
  final String nickname;
  final String location;
  final List<String> imageUrls;
  final String content;
  final String likeCount;
  final String commentCount;

  const BoardCard({
    super.key, 
    required this.profileImageUrl,
    required this.nickname,
    required this.location,
    required this.imageUrls, 
    required this.content, 
    required this.likeCount, 
    required this.commentCount
  });

  @override
  State<BoardCard> createState() => _BoardCardState();

}

class _BoardCardState extends State<BoardCard> {
        
  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      width: screenWidth * 0.98,      
      child: Column(
        children: [
          BoardCardProfile(
            screenHeight: screenHeight, 
            profileImageUrl: widget.profileImageUrl, 
            nickname: widget.nickname, 
            location: widget.location
          ),
          if (widget.imageUrls.isNotEmpty) BoardCardImage(
            screenHeight: screenHeight, 
            imageUrls: widget.imageUrls,
          ),
          BoardCardContent(
            content: widget.content,
            likeCount: widget.likeCount,
            commentCount: widget.commentCount,
            maxLine: widget.imageUrls.isNotEmpty ? 2 : 5,
          ),
        ],
      )
    );
  }

}