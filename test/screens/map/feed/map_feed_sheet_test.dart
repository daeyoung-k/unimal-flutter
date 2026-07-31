import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unimal/screens/map/feed/map_feed_section_row.dart';
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

MapFeedResponse _feedWithTwoSections() => MapFeedResponse(
      dong: '역삼동',
      sections: [
        MapFeedSection(
          type: MapFeedSectionType.near,
          title: '가까운',
          hasMore: false,
          items: [_item('a')],
        ),
        MapFeedSection(
          type: MapFeedSectionType.latest,
          title: '최신',
          hasMore: false,
          items: [_item('b')],
        ),
      ],
    );

/// 새로고침 관련 테스트는 시트를 펼쳐야 헤더가 레이아웃되므로, 광고 슬롯이
/// 실제 애드몹을 만들지 않도록 스텁을 꽂는다 (SDK 초기화 없이 돌리기 위함).
Widget _adStub(BuildContext _) =>
    const SizedBox(key: ValueKey('ad'), width: 320, height: 50);

/// 시트를 최대까지 펼치고 광고 지연 마운트(260ms)까지 흘려보낸다.
Future<void> _expand(
  WidgetTester tester,
  DraggableScrollableController controller,
) async {
  controller.jumpTo(0.9);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

MapFeedSection _section(
  MapFeedSectionType type,
  String title,
  List<String> boardIds,
) =>
    MapFeedSection(
      type: type,
      title: title,
      hasMore: false,
      items: boardIds.map(_item).toList(),
    );

/// 섹션별 새로고침 테스트용 공통 위젯 트리. 광고 스텁은 항상 꽂는다.
Widget _sheetApp({
  required ValueNotifier<MapFeedQuery?> query,
  required DraggableScrollableController controller,
  required Future<MapFeedResponse?> Function(MapFeedQuery) fetcher,
  Future<MapFeedSectionResult> Function(MapFeedQuery, MapFeedSectionType)?
      sectionFetcher,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            MapFeedSheet(
              query: query,
              controller: controller,
              onItemTap: (_) {},
              fetcher: fetcher,
              sectionFetcher: sectionFetcher,
              adBuilder: _adStub,
            ),
          ],
        ),
      ),
    );

/// 화면에 그려진 섹션들을 위에서 아래 순서대로.
List<MapFeedSectionType> _typesInOrder(WidgetTester tester) => tester
    .widgetList<MapFeedSectionRow>(find.byType(MapFeedSectionRow))
    .map((row) => row.section.type)
    .toList();

/// 특정 섹션이 지금 들고 있는 boardId 목록.
List<String> _idsOf(WidgetTester tester, MapFeedSectionType type) => tester
    .widgetList<MapFeedSectionRow>(find.byType(MapFeedSectionRow))
    .firstWhere((row) => row.section.type == type)
    .section
    .items
    .map((item) => item.boardId)
    .toList();

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

  // ── 섹션별 부분 새로고침 ────────────────────────────────────────────

  testWidgets('섹션마다 새로고침 버튼이 하나씩 있다', (tester) async {
    final query = ValueNotifier<MapFeedQuery?>(null);
    final controller = DraggableScrollableController();
    addTearDown(query.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_sheetApp(
      query: query,
      controller: controller,
      fetcher: (_) async => _feedWithTwoSections(),
    ));

    query.value =
        const MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 14);
    await tester.pumpAndSettle();
    await _expand(tester, controller);

    expect(find.byType(MapFeedSectionRow), findsNWidgets(2));
    // 버튼과 갱신 대상이 1:1 — 서버에 섹션 단건 조회가 있으므로.
    expect(
      find.byKey(mapFeedRefreshButtonKey(MapFeedSectionType.near)),
      findsOneWidget,
    );
    expect(
      find.byKey(mapFeedRefreshButtonKey(MapFeedSectionType.latest)),
      findsOneWidget,
    );
  });

  testWidgets('누른 섹션만 갈리고 나머지는 그대로 남는다', (tester) async {
    final query = ValueNotifier<MapFeedQuery?>(null);
    final controller = DraggableScrollableController();
    addTearDown(query.dispose);
    addTearDown(controller.dispose);

    final requested = <MapFeedSectionType>[];

    await tester.pumpWidget(_sheetApp(
      query: query,
      controller: controller,
      fetcher: (_) async => _feedWithTwoSections(),
      sectionFetcher: (_, type) async {
        requested.add(type);
        return MapFeedSectionResult.loaded(
          _section(MapFeedSectionType.latest, '방금 올라온 소식', ['new1', 'new2']),
        );
      },
    ));

    query.value =
        const MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 14);
    await tester.pumpAndSettle();
    await _expand(tester, controller);

    expect(_idsOf(tester, MapFeedSectionType.near), ['a']);
    expect(_idsOf(tester, MapFeedSectionType.latest), ['b']);

    await tester.tap(
      find.byKey(mapFeedRefreshButtonKey(MapFeedSectionType.latest)),
    );
    await tester.pumpAndSettle();

    expect(requested, [MapFeedSectionType.latest]);
    // LATEST 만 갈렸다.
    expect(_idsOf(tester, MapFeedSectionType.latest), ['new1', 'new2']);
    // NEAR 는 건드리지 않았다.
    expect(_idsOf(tester, MapFeedSectionType.near), ['a']);
    // 자리도 그대로다 — 지우고 뒤에 붙이면 새로고침마다 섹션이 위아래로 뛴다.
    expect(_typesInOrder(tester), [
      MapFeedSectionType.near,
      MapFeedSectionType.latest,
    ]);
  });

  testWidgets('섹션이 사라지면(성공+null) 그 자리만 제거된다', (tester) async {
    final query = ValueNotifier<MapFeedQuery?>(null);
    final controller = DraggableScrollableController();
    addTearDown(query.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_sheetApp(
      query: query,
      controller: controller,
      fetcher: (_) async => _feedWithTwoSections(),
      // 적응형 섹션이라 조건을 못 채우면 서버가 data:null 을 200 으로 준다.
      sectionFetcher: (_, __) async => const MapFeedSectionResult.loaded(null),
    ));

    query.value =
        const MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 14);
    await tester.pumpAndSettle();
    await _expand(tester, controller);
    expect(find.byType(MapFeedSectionRow), findsNWidgets(2));

    await tester.tap(
      find.byKey(mapFeedRefreshButtonKey(MapFeedSectionType.latest)),
    );
    await tester.pumpAndSettle();

    expect(_typesInOrder(tester), [MapFeedSectionType.near]);
  });

  testWidgets('통신 실패면 그 섹션을 지우지 않고 그대로 둔다', (tester) async {
    final query = ValueNotifier<MapFeedQuery?>(null);
    final controller = DraggableScrollableController();
    addTearDown(query.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_sheetApp(
      query: query,
      controller: controller,
      fetcher: (_) async => _feedWithTwoSections(),
      sectionFetcher: (_, __) async => const MapFeedSectionResult.failed(),
    ));

    query.value =
        const MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 14);
    await tester.pumpAndSettle();
    await _expand(tester, controller);

    await tester.tap(
      find.byKey(mapFeedRefreshButtonKey(MapFeedSectionType.latest)),
    );
    await tester.pumpAndSettle();

    // 실패를 "섹션 없음"으로 뭉뚱그리면 잠깐의 오류에 멀쩡한 섹션이 사라진다.
    expect(_typesInOrder(tester), [
      MapFeedSectionType.near,
      MapFeedSectionType.latest,
    ]);
    expect(_idsOf(tester, MapFeedSectionType.latest), ['b']);
  });

  testWidgets('같은 섹션 연타는 무시되고, 다른 섹션은 동시에 돌 수 있다', (tester) async {
    final query = ValueNotifier<MapFeedQuery?>(null);
    final controller = DraggableScrollableController();
    addTearDown(query.dispose);
    addTearDown(controller.dispose);

    final calls = <MapFeedSectionType>[];
    final gates = <MapFeedSectionType, Completer<MapFeedSectionResult>>{};

    await tester.pumpWidget(_sheetApp(
      query: query,
      controller: controller,
      fetcher: (_) async => _feedWithTwoSections(),
      sectionFetcher: (_, type) {
        calls.add(type);
        final gate = Completer<MapFeedSectionResult>();
        gates[type] = gate;
        return gate.future;
      },
    ));

    query.value =
        const MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 14);
    await tester.pumpAndSettle();
    await _expand(tester, controller);

    await tester.tap(
      find.byKey(mapFeedRefreshButtonKey(MapFeedSectionType.latest)),
    );
    await tester.pump();
    expect(calls, [MapFeedSectionType.latest]);

    // 같은 섹션 연타 — 요청이 더 나가지 않는다 (버튼이 비활성이라 탭이 빗나갈 수 있다).
    await tester.tap(
      find.byKey(mapFeedRefreshButtonKey(MapFeedSectionType.latest)),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(calls, [MapFeedSectionType.latest]);

    // 다른 섹션은 막지 않는다 — 섹션별 요청은 서로 간섭하지 않으므로,
    // 하나가 도는 동안 전부 막으면 부분 갱신을 만든 의미가 없다.
    await tester.tap(
      find.byKey(mapFeedRefreshButtonKey(MapFeedSectionType.near)),
    );
    await tester.pump();
    expect(calls, [MapFeedSectionType.latest, MapFeedSectionType.near]);

    gates[MapFeedSectionType.latest]!
        .complete(const MapFeedSectionResult.failed());
    gates[MapFeedSectionType.near]!
        .complete(const MapFeedSectionResult.failed());
    await tester.pumpAndSettle();
  });

  testWidgets('자동 갱신에는 아이콘이 돌지 않는다', (tester) async {
    final query = ValueNotifier<MapFeedQuery?>(null);
    final controller = DraggableScrollableController();
    addTearDown(query.dispose);
    addTearDown(controller.dispose);

    final gates = <Completer<MapFeedResponse?>>[];
    Future<MapFeedResponse?> fetcher(MapFeedQuery q) {
      final gate = Completer<MapFeedResponse?>();
      gates.add(gate);
      return gate.future;
    }

    await tester.pumpWidget(_sheetApp(
      query: query,
      controller: controller,
      fetcher: fetcher,
    ));

    query.value =
        const MapFeedQuery(latitude: 37.5, longitude: 127.0, zoom: 14);
    await tester.pump();
    gates.first.complete(_feedWithSections());
    await tester.pumpAndSettle();

    await _expand(tester, controller);

    // 펼친 상태에서 좌표가 바뀌면 자동 갱신이 돈다 — 사용자가 누른 게 아니므로
    // 회전은 없어야 한다 (30초마다 아이콘이 도는 건 노이즈다).
    query.value =
        const MapFeedQuery(latitude: 37.7, longitude: 127.7, zoom: 14);
    await tester.pump();

    final row = tester.widget<MapFeedSectionRow>(
      find.byType(MapFeedSectionRow).first,
    );
    expect(row.isRefreshing, isFalse);

    gates.last.complete(_feedWithSections());
    await tester.pumpAndSettle();
  });
}
