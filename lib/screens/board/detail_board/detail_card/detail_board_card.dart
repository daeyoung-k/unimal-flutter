import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/screens/board/detail_board/detail_card/datail_content.dart';
import 'package:unimal/screens/board/detail_board/detail_card/detail_images.dart';
import 'package:unimal/screens/board/detail_board/detail_card/detail_profile.dart';
import 'package:unimal/state/nav_controller.dart';

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
              onMapTap: (boardPost.show == 'PUBLIC' &&
                      boardPost.latitude != null &&
                      boardPost.longitude != null &&
                      boardPost.latitude != 0.0 &&
                      boardPost.longitude != 0.0)
                  ? () {
                      final nav = Get.find<NavController>();
                      // boardId 를 먼저 — 지도 화면은 pendingMapLat 변화를
                      // 트리거로 쓰므로 나중에 넣으면 못 읽는다.
                      nav.pendingMapBoardId.value = boardPost.boardId;
                      nav.pendingMapLng.value = boardPost.longitude;
                      nav.pendingMapLat.value = boardPost.latitude;
                      nav.selectedIndex.value = 0;
                      // Get.back() 은 한 단계만 pop 한다. 상세 화면 아래에 내 지도
                      // (/my-story-map) 같은 다른 라우트가 끼어 있으면 메인 지도가
                      // 아니라 거기로 떨어진다. 루트(RootScreen)까지 한 번에 걷어낸다.
                      //
                      // Get.offAllNamed('/map') 은 쓰면 안 된다 — 지도 화면이 새로
                      // 만들어지면서 ever(pendingMapLat) 워커가 값이 이미 세팅된
                      // '뒤에' 등록돼 영영 발화하지 않는다(카메라가 안 움직인다).
                      // Get.until 은 기존 RootScreen 을 살려두므로 위에서 세팅한
                      // pendingMapLat 이 이미 등록된 워커를 정상적으로 깨운다.
                      Get.until((route) => route.isFirst);
                    }
                  : null,
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
