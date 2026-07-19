import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/utils/api_client.dart';

void main() {
  group('ApiClient auth failure detection', () {
    test(
      'treats token-expired response body as auth failure even when HTTP status is not 401',
      () {
        final response = http.Response.bytes(
          utf8.encode(jsonEncode({'code': 500, 'message': '토큰이 만료 되었습니다.'})),
          500,
        );

        expect(ApiClient.shouldRefreshForAuthFailure(response), isTrue);
      },
    );

    test('keeps HTTP 401 as auth failure', () {
      final response = http.Response('', 401);

      expect(ApiClient.shouldRefreshForAuthFailure(response), isTrue);
    });

    test('treats plain token-expired response body as auth failure', () {
      final response = http.Response.bytes(
        utf8.encode('토큰이 만료 되었습니다.'),
        500,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );

      expect(ApiClient.shouldRefreshForAuthFailure(response), isTrue);
    });

    test('does not treat ordinary server errors as auth failure', () {
      final response = http.Response.bytes(
        utf8.encode(jsonEncode({'code': 500, 'message': '일시적인 서버 오류입니다.'})),
        500,
      );

      expect(ApiClient.shouldRefreshForAuthFailure(response), isFalse);
    });
  });
}
