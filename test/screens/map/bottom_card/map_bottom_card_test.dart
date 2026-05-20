import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/bottom_card/map_bottom_card.dart';
import 'package:unimal/screens/map/bottom_card/post_image_carousel.dart';
import 'package:unimal/service/board/model/file_info.dart';
import 'package:unimal/service/map/models/map_post.dart';

MapPost _imagePost() => MapPost(
      id: 'post-1',
      nickname: '권대영',
      profileImage: null,
      title: '서울역 꽃이유',
      content: '꽃',
      streetName: '서울특별시 중구 봉래동2가 122-12',
      latitude: 37.5547,
      longitude: 126.9707,
      createdAt: '2026-04-06T12:00:00',
      fileInfoList: [
        FileInfo(fileId: 'file-1', fileUrl: 'https://example.com/flower.jpg'),
      ],
      likeCount: 2,
      replyCount: 4,
      score: 10,
      isOwner: false,
      isLike: false,
    );

void main() {
  testWidgets('default image-post card shows the image carousel above the info',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Scaffold(
            body: MapBottomCard(
              groups: [
                [_imagePost()],
              ],
              initialGroupIndex: 0,
              minTopMargin: 100,
              onClose: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PostImageCarousel), findsOneWidget);
    expect(find.text('서울역 꽃이유'), findsOneWidget);
    expect(find.text('꽃'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });
}
