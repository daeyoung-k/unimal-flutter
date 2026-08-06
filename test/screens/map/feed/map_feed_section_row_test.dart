import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/feed/map_feed_card.dart';
import 'package:unimal/screens/map/feed/map_feed_section_row.dart';
import 'package:unimal/service/map/models/map_feed.dart';

MapFeedItem _item(
  String id, {
  String? thumb,
  String title = '제목',
  int distanceMeters = 0,
}) =>
    MapFeedItem(
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
      distanceMeters: distanceMeters,
    );

MapFeedSection _oneItemSection(MapFeedItem item) => MapFeedSection(
      type: MapFeedSectionType.near,
      title: '지금 여기 이야기',
      hasMore: false,
      items: [item],
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

  // hasMore 는 계속 파싱하지만 **화살표는 그리지 않는다** (2026-07-30 결정).
  // 탭 동작이 없는 `>` 는 이 앱의 다른 모든 `>`(전부 눌린다)와 어긋나 버그로 읽힌다.
  //
  // 예전엔 "hasMore=true 면 화살표를 보인다" 테스트가 있었는데, 화살표를 걷어낼 때
  // 같이 지우지 않아 그때부터 계속 깨진 채 방치돼 있었다. 되살리는 대신 **결정을
  // 지키는 회귀 테스트**로 바꾼다 — 나중에 무심코 다시 붙이면 여기서 걸린다.
  // (더보기 페이지네이션이 실제로 생기면 그때 '눌린다'는 테스트로 교체할 것)
  testWidgets('hasMore 여부와 무관하게 화살표를 그리지 않는다', (tester) async {
    for (final hasMore in [false, true]) {
      await tester.pumpWidget(_wrap(MapFeedSectionRow(
        section: _section(hasMore: hasMore),
        onItemTap: (_) {},
      )));

      expect(
        find.byIcon(Icons.chevron_right),
        findsNothing,
        reason: 'hasMore=$hasMore',
      );
    }
  });

  testWidgets('섹션 타입에 맞는 뱃지 아이콘을 그린다', (tester) async {
    Future<void> pumpType(MapFeedSectionType type) => tester.pumpWidget(_wrap(
          MapFeedSectionRow(
            section: MapFeedSection(
              type: type,
              title: '제목',
              hasMore: false,
              items: [_item('a')],
            ),
            onItemTap: (_) {},
          ),
        ));

    await pumpType(MapFeedSectionType.near);
    expect(find.byIcon(Icons.place_rounded), findsOneWidget);

    await pumpType(MapFeedSectionType.all);
    expect(find.byIcon(Icons.public_rounded), findsOneWidget);

    await pumpType(MapFeedSectionType.latest);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
  });

  testWidgets('onRefresh 가 없으면 새로고침 버튼을 그리지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(MapFeedSectionRow(
      section: _section(hasMore: false),
      onItemTap: (_) {},
    )));

    expect(
      find.byKey(mapFeedRefreshButtonKey(MapFeedSectionType.latest)),
      findsNothing,
    );

    await tester.pumpWidget(_wrap(MapFeedSectionRow(
      section: _section(hasMore: false),
      onItemTap: (_) {},
      onRefresh: () {},
    )));

    expect(
      find.byKey(mapFeedRefreshButtonKey(MapFeedSectionType.latest)),
      findsOneWidget,
    );
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

  // 거리 표시 — 이 피드는 반경 제한이 없어(서버가 KNN 정렬만 한다) 수백 km 떨어진
  // 글이 섞일 수 있고, 거리를 숨기면 카드를 탭했을 때 지도가 먼 곳으로 튀어 혼란스럽다.
  // 포맷 헬퍼가 private 이라 렌더된 텍스트로 검증한다.
  group('거리 표시', () {
    Future<void> pumpWithDistance(WidgetTester tester, int meters) async {
      await tester.pumpWidget(_wrap(MapFeedSectionRow(
        section: _oneItemSection(_item('d1', distanceMeters: meters)),
        onItemTap: (_) {},
      )));
    }

    testWidgets('1km 미만은 정수 미터로 보여준다', (tester) async {
      await pumpWithDistance(tester, 123);
      expect(find.textContaining('123m'), findsOneWidget);
    });

    testWidgets('1km 이상은 킬로미터로 보여준다', (tester) async {
      await pumpWithDistance(tester, 1234);
      expect(find.textContaining('1.2km'), findsOneWidget);
    });

    testWidgets('딱 떨어지는 킬로미터는 소수점을 생략한다', (tester) async {
      // '1.0km' 는 정밀도가 있는 것처럼 보여 어색하다.
      await pumpWithDistance(tester, 2000);
      expect(find.textContaining('2km'), findsOneWidget);
      expect(find.textContaining('2.0km'), findsNothing);
    });

    testWidgets('1000m 경계는 킬로미터로 넘어간다', (tester) async {
      await pumpWithDistance(tester, 1000);
      expect(find.textContaining('1km'), findsOneWidget);
      expect(find.textContaining('1000m'), findsNothing);
    });
  });
}
