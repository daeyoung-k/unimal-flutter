import 'package:flutter/material.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/screens/detail_board/detail_card/datail_content.dart';
import 'package:unimal/screens/detail_board/detail_card/detail_images.dart';
import 'package:unimal/screens/detail_board/detail_card/detail_profile.dart';

class DetailBoardCard extends StatelessWidget {
  final BoardPost boardPost;

  const DetailBoardCard({
    super.key,
    required this.boardPost,
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
              profileImageUrl: boardPost.profileImage,
              nickname: boardPost.nickname,
              location: boardPost.streetName,
            ),
            if (boardPost.fileInfoList.isNotEmpty)
              // 이미지 영역
              DetailImages(
                imageUrls: boardPost.fileInfoList.map((e) => e.fileUrl).toList(),
                screenHeight: screenHeight,
              ),
            // 콘텐츠 영역
            DetailContent(
              title: boardPost.title,
              content: boardPost.content,
              isLike: boardPost.isLike,
              likeCount: boardPost.likeCount.toString(),
              replyCount: boardPost.replyCount.toString(),
            ),
          ],
        ),
      ),
    );
  }
}



