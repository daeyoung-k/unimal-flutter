import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/service/board/board_api_service.dart';

void main() {
  test('HTTP 200의 빈 data는 성공한 빈 목록이다', () {
    final result = decodeMapPostsResponse(http.Response('{"data":[]}', 200));

    expect(result, isNotNull);
    expect(result, isEmpty);
  });

  test('HTTP 실패는 null이다', () {
    final result = decodeMapPostsResponse(
      http.Response('{"message":"error"}', 500),
    );

    expect(result, isNull);
  });

  test('잘못된 성공 JSON은 null이다', () {
    final result = decodeMapPostsResponse(http.Response('{not-json}', 200));

    expect(result, isNull);
  });
}
