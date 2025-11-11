import 'package:flutter/material.dart';
import 'package:unimal/screens/detail_board/detail_card/datail_content.dart';
import 'package:unimal/screens/detail_board/detail_card/detail_images.dart';
import 'package:unimal/screens/detail_board/detail_card/detail_profile.dart';

class DetailBoardCard extends StatelessWidget {
  final String profileImageUrl;
  final String nickname;
  final String location;
  final List<String> imageUrls;
  final String content;
  final String likeCount;
  final String commentCount;

  const DetailBoardCard({
    super.key,
    required this.profileImageUrl,
    required this.nickname,
    required this.location,
    required this.imageUrls,
    required this.content,
    required this.likeCount,
    required this.commentCount,
  });

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 프로필 영역
            DetailProfile(
              profileImageUrl: profileImageUrl,
              nickname: nickname,
              location: location,
            ),
            if (imageUrls.isNotEmpty)
              // 이미지 영역
              DetailImages(
                imageUrls: imageUrls,
                screenHeight: screenHeight,
              ),
            // 콘텐츠 영역
            DetailContent(
              content: content,
              likeCount: likeCount,
              commentCount: commentCount,
            ),
          ],
        ),
      ),
    );
  }
}



