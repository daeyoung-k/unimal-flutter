import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/board/widget/detailcard/detail_board_card.dart';

class DetailBoardScreen extends StatelessWidget {
  const DetailBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args = (Get.arguments as Map<String, dynamic>?) ?? {};

    final int boardId = (args['boardId'] as int?) ?? 0;
    final String content = (args['content'] as String?)?.trim() ?? '';
    final List<dynamic> imageUrlsDynamic = (args['imageUrls'] as List<dynamic>?) ?? const [];
    final List<String> imageUrls = imageUrlsDynamic.map((e) => e.toString()).toList();
    final String streetName = (args['streetName'] as String?) ?? '';
    final String author = (args['author'] as String?) ?? '익명';
    final String likeCount = (args['likeCount'] as String?) ?? '0';
    final String commentCount = (args['commentCount'] as String?) ?? '0';
    final String profileImageUrl = (args['profileImageUrl'] as String?)?.trim().isNotEmpty == true
        ? (args['profileImageUrl'] as String)
        : 'https://via.placeholder.com/150';

    return Scaffold(
      backgroundColor: const Color(0xFF4D91FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '상세 소식',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 20, 10, 32),
            child: DetailBoardCard(
              profileImageUrl: profileImageUrl,
              nickname: author,
              location: streetName.isNotEmpty ? streetName : '위치 정보 없음',
              imageUrls: imageUrls,
              content: content,
              likeCount: likeCount,
              commentCount: commentCount,
            ),
          ),
        ),
      ),
    );
  }

}


