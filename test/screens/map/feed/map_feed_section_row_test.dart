import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/feed/map_feed_card.dart';
import 'package:unimal/screens/map/feed/map_feed_section_row.dart';
import 'package:unimal/service/map/models/map_feed.dart';

MapFeedItem _item(String id, {String? thumb, String title = '제목'}) => MapFeedItem(
      boardId: id,
      thumbnailUrl: thumb,
      title: title,
      content: '본문 내용',
      streetName: '서울 강남구',
      latitude: 37.5,
      longitude: 127.0,
      nickname: '닉',
      likeCount: 3,
      replyCount: 1,
      createdAt: '2026-07-29T10:00:00',
    );

MapFeedSection _section({required bool hasMore, int count = 2}) => MapFeedSection(
      type: MapFeedSectionType.latest,
      title: '방금 올라온 소식',
      hasMore: hasMore,
      items: [for (int i = 0; i < count; i++) _item('id$i')],
    );

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('헤더 제목과 카드를 그린다', (tester) async {
    await tester.pumpWidget(_wrap(MapFeedSectionRow(
      section: _section(hasMore: false),
      onItemTap: (_) {},
    )));

    expect(find.text('방금 올라온 소식'), findsOneWidget);
    expect(find.byType(MapFeedCard), findsNWidgets(2));
  });

  testWidgets('hasMore가 false면 화살표를 숨긴다', (tester) async {
    await tester.pumpWidget(_wrap(MapFeedSectionRow(
      section: _section(hasMore: false),
      onItemTap: (_) {},
    )));

    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('hasMore가 true면 화살표를 보인다', (tester) async {
    await tester.pumpWidget(_wrap(MapFeedSectionRow(
      section: _section(hasMore: true),
      onItemTap: (_) {},
    )));

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('카드를 탭하면 해당 아이템으로 콜백한다', (tester) async {
    MapFeedItem? tapped;
    await tester.pumpWidget(_wrap(MapFeedSectionRow(
      section: _section(hasMore: false),
      onItemTap: (i) => tapped = i,
    )));

    await tester.tap(find.byType(MapFeedCard).first);
    await tester.pump();

    expect(tapped?.boardId, 'id0');
  });

  testWidgets('썸네일이 없으면 본문 스니펫을 보여준다', (tester) async {
    final section = MapFeedSection(
      type: MapFeedSectionType.latest,
      title: '방금 올라온 소식',
      hasMore: false,
      items: [_item('t1', thumb: null)],
    );

    await tester.pumpWidget(_wrap(MapFeedSectionRow(
      section: section,
      onItemTap: (_) {},
    )));

    // 제목이 비어있지 않으므로 본문은 썸네일 대체 타일에서만 나온다.
    expect(find.text('본문 내용'), findsOneWidget);
  });
}
