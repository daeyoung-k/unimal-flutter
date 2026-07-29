import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/feed/map_feed_sheet.dart';
import 'package:unimal/service/map/models/map_feed.dart';

MapFeedItem _item(String boardId) => MapFeedItem(
      boardId: boardId,
      title: '제목',
      content: '내용',
      streetName: '서울시 강남구',
      latitude: 37.5,
      longitude: 127.0,
      nickname: '닉네임',
      likeCount: 0,
      replyCount: 0,
      createdAt: '2026-07-29T00:00:00',
    );

MapFeedResponse _feedWithSections() => MapFeedResponse(
      dong: '역삼동',
      sections: [
        MapFeedSection(
          type: MapFeedSectionType.latest,
          title: '최신',
          hasMore: false,
          items: [_item('a')],
        ),
      ],
    );

void main() {
  test('MapFeedQuery는 같은 값이면 동등하다', () {
    const a = MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 16);
    const b = MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 16);
    const c = MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 17);

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });

  testWidgets('query가 null이면 아무것도 렌더하지 않는다', (tester) async {
    final query = ValueNotifier<MapFeedQuery?>(null);
    final controller = DraggableScrollableController();
    addTearDown(query.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            MapFeedSheet(
              query: query,
              controller: controller,
              onItemTap: (_) {},
            ),
          ],
        ),
      ),
    ));

    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });

  testWidgets('첫 조회가 null이어도 다음 쿼리에서 다시 조회한다 (회귀)', (tester) async {
    final query = ValueNotifier<MapFeedQuery?>(null);
    final controller = DraggableScrollableController();
    addTearDown(query.dispose);
    addTearDown(controller.dispose);

    var callCount = 0;
    Future<MapFeedResponse?> fetcher(MapFeedQuery q) async {
      callCount++;
      if (callCount == 1) return null;
      return _feedWithSections();
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            MapFeedSheet(
              query: query,
              controller: controller,
              onItemTap: (_) {},
              fetcher: fetcher,
            ),
          ],
        ),
      ),
    ));

    query.value =
        const MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 14);
    await tester.pumpAndSettle();

    expect(callCount, 1);
    expect(find.byType(DraggableScrollableSheet), findsNothing);

    query.value =
        const MapFeedQuery(latitude: 37.6, longitude: 127.1, zoom: 14);
    await tester.pumpAndSettle();

    expect(callCount, 2);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
  });

  testWidgets('내용이 생긴 뒤 접힌 상태에서는 갱신하지 않는다', (tester) async {
    final query = ValueNotifier<MapFeedQuery?>(null);
    final controller = DraggableScrollableController();
    addTearDown(query.dispose);
    addTearDown(controller.dispose);

    var callCount = 0;
    Future<MapFeedResponse?> fetcher(MapFeedQuery q) async {
      callCount++;
      return _feedWithSections();
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            MapFeedSheet(
              query: query,
              controller: controller,
              onItemTap: (_) {},
              fetcher: fetcher,
            ),
          ],
        ),
      ),
    ));

    query.value =
        const MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 14);
    await tester.pumpAndSettle();

    expect(callCount, 1);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);

    // 시트는 peek(접힘) 상태다 — 컨트롤러가 이제 부착됐으니 펼치지 않는 한
    // _isExpanded 는 false 다. 쿼리를 바꿔도 갱신되지 않아야 한다.
    query.value =
        const MapFeedQuery(latitude: 37.9, longitude: 127.9, zoom: 14);
    await tester.pumpAndSettle();

    expect(callCount, 1);
  });

  testWidgets('같은 쿼리로는 중복 조회하지 않는다', (tester) async {
    final query = ValueNotifier<MapFeedQuery?>(null);
    final controller = DraggableScrollableController();
    addTearDown(query.dispose);
    addTearDown(controller.dispose);

    var callCount = 0;
    Future<MapFeedResponse?> fetcher(MapFeedQuery q) async {
      callCount++;
      return _feedWithSections();
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            MapFeedSheet(
              query: query,
              controller: controller,
              onItemTap: (_) {},
              fetcher: fetcher,
            ),
          ],
        ),
      ),
    ));

    const q = MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 14);
    query.value = q;
    await tester.pumpAndSettle();
    expect(callCount, 1);

    // 동일한 값으로 다시 대입 — ValueNotifier 가 `==` 로 같은 값이면 리스너에
    // 알리지 않으므로 호출 수가 그대로여야 한다.
    query.value =
        const MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 14);
    await tester.pumpAndSettle();
    expect(callCount, 1);
  });
}
