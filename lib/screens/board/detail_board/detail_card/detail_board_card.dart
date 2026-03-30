import 'package:flutter/material.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/screens/board/detail_board/detail_card/datail_content.dart';
import 'package:unimal/screens/board/detail_board/detail_card/detail_images.dart';
import 'package:unimal/screens/board/detail_board/detail_card/detail_profile.dart';

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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailProfile(
              profileImageUrl: boardPost.profileImage,
              nickname: boardPost.nickname,
              location: boardPost.streetName,
            ),
            if (boardPost.fileInfoList.isNotEmpty)
              DetailImages(
                imageUrls: boardPost.fileInfoList.map((e) => e.fileUrl).toList(),
                screenHeight: screenHeight,
              ),
            DetailContent(
              title: boardPost.title,
              content: boardPost.content,
              isLike: boardPost.isLike,
              likeCount: boardPost.likeCount.toString(),
              replyCount: boardPost.replyCount.toString(),
              boardId: boardPost.boardId,
              createdAt: boardPost.createdAt,
            ),
          ],
        ),
      ),
    );
  }
}
