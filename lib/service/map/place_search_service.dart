import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:unimal/utils/api_client.dart';
import 'package:unimal/utils/api_uri.dart';

/// 장소 검색 결과 한 건 (백엔드 `GET /map/search/place` 응답).
class PlaceResult {
  final String title;
  final String address;
  final String roadAddress;
  final double lat;
  final double lng;

  PlaceResult({
    required this.title,
    required this.address,
    required this.roadAddress,
    required this.lat,
    required this.lng,
  });

  /// 화면에 보여줄 주소 — 도로명 우선, 없으면 지번.
  String get displayAddress => roadAddress.isNotEmpty ? roadAddress : address;

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    return PlaceResult(
      title: json['title'] as String? ?? '',
      address: json['address'] as String? ?? '',
      roadAddress: json['roadAddress'] as String? ?? '',
      lat: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      lng: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// 장소 검색.
///
/// 예전에는 이 클래스가 openapi.naver.com / maps.apigw.ntruss.com 을 앱에서 직접
/// 호출하고 네이버·NCP 클라이언트 시크릿을 .env(=앱 에셋)에서 읽었다. dotenv 는
/// 암호화가 아니라 평문 에셋이라 APK/IPA 를 풀면 키가 그대로 노출되는 구조였다.
/// 특히 NCP 키는 종량 과금이라 유출이 곧 비용 문제로 이어진다.
///
/// 지금은 키를 서버 환경변수로 옮기고 `/map/search/place` 프록시만 호출한다.
/// 서버에서 Redis 로 6시간 캐싱하므로 외부 API 호출량도 함께 줄었다.
class PlaceSearchService {
  final _logger = Logger();

  /// 서버도 같은 값으로 방어하지만, 왕복 자체를 아끼기 위해 앱에서 먼저 거른다.
  static const int minQueryLength = 2;

  Future<List<PlaceResult>> search(String query) async {
    final keyword = query.trim();
    if (keyword.length < minQueryLength) return [];

    try {
      final url = ApiUri.resolve('map/search/place', {'query': keyword});
      // /map/** 은 게이트웨이에 인증 필터가 없어 비로그인도 호출 가능하다.
      final response = await ApiClient.get(url, <String, String>{});

      if (response.statusCode != 200) {
        _logger.w('[장소검색] 실패: ${response.statusCode}');
        return [];
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final data = body['data'];
      if (data is! List) return [];

      return data
          .map((e) => PlaceResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 검색창은 타이핑 중 계속 호출되는 자리라 알럿 대신 조용히 빈 목록.
      _logger.e('[장소검색] 오류: $e');
      return [];
    }
  }
}
