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
  testWidgets('광고는 접힌 상태에서 렌더되지 않고, 펼치면 렌더된다', (tester) async {
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
              fetcher: (_) async => _feedWithSections(),
              // 실제 애드몹 배너 대신 찾기 쉬운 스텁을 꽂는다.
              adBuilder: (_) => const SizedBox(
                key: ValueKey('ad'),
                width: 320,
                height: 50,
              ),
            ),
          ],
        ),
      ),
    ));

    query.value =
        const MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 14);
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);

    // peek(접힘) — 광고 위젯 자체가 만들어지지 않는다.
    // 안 보이면 클릭도 안 되므로 오탭 차단이 구조적으로 보장된다.
    expect(find.byKey(const ValueKey('ad')), findsNothing);

    // 중간 스냅으로 올린 "직후"에는 아직 붙지 않는다.
    // 네이티브 뷰 생성이 스냅 애니메이션 프레임을 잡아먹지 않도록 미뤄둔 것.
    controller.jumpTo(0.45);
    await tester.pump();
    expect(find.byKey(const ValueKey('ad')), findsNothing);

    // 시트가 멎고 나면 붙는다.
    //
    // pumpAndSettle 은 "예약된 프레임이 있는 동안"만 시간을 진행시킨다. jumpTo 는
    // 애니메이션 없이 값만 바꾸고, 대기 중인 Timer 는 프레임을 예약하지 않으므로
    // 지연 마운트 시간을 명시적으로 밀어줘야 한다.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle(); // AnimatedSize 정착
    expect(find.byKey(const ValueKey('ad')), findsOneWidget);

    // 최대 — 계속 보인다 (이미 붙어 있으므로 다시 기다릴 필요 없다).
    controller.jumpTo(0.9);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ad')), findsOneWidget);

    // 다시 접으면 즉시 사라진다 (여기는 미루지 않는다).
    controller.jumpTo(0.11);
    await tester.pump();
    expect(find.byKey(const ValueKey('ad')), findsNothing);
  });

  testWidgets('중간 높이로도 스냅할 수 있다', (tester) async {
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
              fetcher: (_) async => _feedWithSections(),
            ),
          ],
        ),
      ),
    ));

    query.value =
        const MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 14);
    await tester.pumpAndSettle();

    final sheet =
        tester.widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet));
    // peek / 중간 / 최대 세 단계
    expect(sheet.snapSizes, hasLength(3));
    expect(sheet.snap, isTrue);

    controller.jumpTo(0.45);
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(0.45, 0.001));
  });
}
