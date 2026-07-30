import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/service/map/map_feed_mock.dart';
import 'package:unimal/service/map/models/map_feed.dart';

const _fullJson = '''
{"code":200,"message":"Success","data":{
  "dong":"역삼동",
  "sections":[
    {"type":"LATEST","title":"방금 올라온 소식","has_more":true,"items":[
      {"board_id":"aB3xY9","thumbnail_url":"https://cdn.example/a.jpg",
       "title":"역삼동 골목 고양이","content":"퇴근길에 만난 삼색이",
       "street_name":"서울 강남구 역삼로 123","dong":"역삼동",
       "latitude":37.5006,"longitude":127.0366,
       "nickname":"대영","profile_image":"https://cdn.example/p.jpg",
       "like_count":12,"reply_count":3,"created_at":"2026-07-29T14:33:00"}
    ]},
    {"type":"HOT","title":"지금 인기 있는 스토리","has_more":false,"items":[]}
  ]}}
''';

void main() {
  test('snake_case 키를 정상 파싱한다', () {
    final result = decodeMapFeedResponse(http.Response.bytes(utf8.encode(_fullJson), 200));

    expect(result, isNotNull);
    expect(result!.dong, '역삼동');
    expect(result.sections.length, 2);

    final latest = result.sections.first;
    expect(latest.type, MapFeedSectionType.latest);
    expect(latest.title, '방금 올라온 소식');
    expect(latest.hasMore, isTrue);
    expect(latest.items.length, 1);

    final item = latest.items.first;
    expect(item.boardId, 'aB3xY9');
    expect(item.thumbnailUrl, 'https://cdn.example/a.jpg');
    expect(item.title, '역삼동 골목 고양이');
    expect(item.nickname, '대영');
    expect(item.profileImage, 'https://cdn.example/p.jpg');
    expect(item.streetName, '서울 강남구 역삼로 123');
    expect(item.latitude, 37.5006);
    expect(item.longitude, 127.0366);
    expect(item.likeCount, 12);
    expect(item.replyCount, 3);
    expect(item.createdAt, '2026-07-29T14:33:00');
  });

  test('모르는 섹션 타입은 그 섹션만 건너뛴다', () {
    const json = '''
    {"data":{"dong":null,"sections":[
      {"type":"SOMETHING_NEW","title":"미래 섹션","has_more":false,"items":[]},
      {"type":"NEARBY","title":"역삼동 이웃들의 스토리","has_more":true,"items":[]}
    ]}}
    ''';

    final result = decodeMapFeedResponse(http.Response.bytes(utf8.encode(json), 200));

    expect(result, isNotNull);
    expect(result!.sections.length, 1);
    expect(result.sections.single.type, MapFeedSectionType.nearby);
  });

  test('nullable 필드 누락을 견딘다', () {
    const json = '''
    {"data":{"sections":[
      {"type":"LATEST","title":"방금 올라온 소식","has_more":false,"items":[
        {"board_id":"x1","title":"","content":"사진 없는 글",
         "street_name":"","latitude":37.5,"longitude":127.0,
         "nickname":"익명","like_count":0,"reply_count":0,
         "created_at":"2026-07-29T10:00:00"}
      ]}
    ]}}
    ''';

    final result = decodeMapFeedResponse(http.Response.bytes(utf8.encode(json), 200));

    expect(result, isNotNull);
    expect(result!.dong, isNull);
    final item = result.sections.single.items.single;
    expect(item.thumbnailUrl, isNull);
    expect(item.profileImage, isNull);
    expect(item.dong, isNull);
    expect(item.content, '사진 없는 글');
  });

  test('HTTP 실패는 null이다', () {
    expect(
      decodeMapFeedResponse(http.Response('{"message":"error"}', 500)),
      isNull,
    );
  });

  test('잘못된 JSON은 null이다', () {
    expect(decodeMapFeedResponse(http.Response('{not-json}', 200)), isNull);
  });

  test('data가 없으면 null이다', () {
    expect(decodeMapFeedResponse(http.Response('{"code":200}', 200)), isNull);
  });

  test('목 JSON은 실제 파서를 통과하고 3섹션을 준다', () {
    // Response.bytes + utf8.encode — 한글 body 는 기본 latin1 인코딩으로
    // 만들 수 없다 (Task 1 에서 확인된 제약, 같은 파일 다른 테스트와 동일 방식).
    final result = decodeMapFeedResponse(
      http.Response.bytes(utf8.encode(kMapFeedMockJson), 200),
    );

    expect(result, isNotNull);
    expect(result!.dong, '역삼동');
    expect(
      result.sections.map((s) => s.type).toList(),
      [
        MapFeedSectionType.latest,
        MapFeedSectionType.hot,
        MapFeedSectionType.nearby,
      ],
    );
    // 썸네일 없는 카드가 렌더 확인용으로 최소 1건 있어야 한다.
    final allItems = result.sections.expand((s) => s.items);
    expect(allItems.any((i) => i.thumbnailUrl == null), isTrue);
    // 제목 없는 카드도 1건 (본문 폴백 확인용).
    expect(allItems.any((i) => i.title.isEmpty), isTrue);
  });

  test('board_id 없는 아이템은 버린다 (키 표기 계약 위반 조기 경보)', () {
    // 서버가 camelCase 로 내려준 상황을 모사 — type/title/content 는 한 단어라
    // 그대로 매칭되므로 섹션은 살아남고 아이템만 board_id 를 잃는다.
    const json = '''
    {"data":{"sections":[
      {"type":"LATEST","title":"방금 올라온 소식","has_more":false,"items":[
        {"boardId":"camel1","title":"제목","content":"본문",
         "latitude":37.5,"longitude":127.0,"nickname":"닉",
         "likeCount":9,"createdAt":"2026-07-30T10:00:00"},
        {"board_id":"ok1","title":"정상","content":"본문",
         "latitude":37.5,"longitude":127.0,"nickname":"닉",
         "like_count":3,"created_at":"2026-07-30T10:00:00"}
      ]}
    ]}}
    ''';

    final result = decodeMapFeedResponse(
      http.Response.bytes(utf8.encode(json), 200),
    );

    expect(result, isNotNull);
    final items = result!.sections.single.items;
    expect(items.length, 1, reason: 'camelCase 아이템은 버려져야 한다');
    expect(items.single.boardId, 'ok1');
  });
}
