import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class NaverLocalSearchResult {
  final String title;
  final String address;
  final String roadAddress;
  final double lat;
  final double lng;

  NaverLocalSearchResult({
    required this.title,
    required this.address,
    required this.roadAddress,
    required this.lat,
    required this.lng,
  });
}

class NaverSearchService {
  static const _localSearchUrl = 'https://openapi.naver.com/v1/search/local.json';
  static const _geocodingUrl = 'https://maps.apigw.ntruss.com/map-geocode/v2/geocode';
  final _logger = Logger();

  Future<List<NaverLocalSearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final results = await Future.wait([
      _searchLocal(query),
      _searchGeocoding(query),
    ]);

    // 장소 검색 + 주소 검색 병합 (title 기준 중복 제거)
    final merged = <String, NaverLocalSearchResult>{};
    for (final list in results) {
      for (final item in list) {
        merged.putIfAbsent(item.title, () => item);
      }
    }
    return merged.values.toList();
  }

  Future<List<NaverLocalSearchResult>> _searchLocal(String query) async {
    try {
      final uri = Uri.parse(_localSearchUrl).replace(queryParameters: {
        'query': query,
        'display': '5',
      });
      final res = await http.get(uri, headers: {
        'X-Naver-Client-Id': dotenv.env['NAVER_LOGIN_CLIENT_ID']!,
        'X-Naver-Client-Secret': dotenv.env['NAVER_LOGIN_CLIENT_SECRET']!,
      });
      if (res.statusCode != 200) return [];

      final items = jsonDecode(utf8.decode(res.bodyBytes))['items'] as List? ?? [];
      return items.map((e) {
        final title = e['title'].toString().replaceAll(RegExp(r'<[^>]*>'), '');
        final lat = int.parse(e['mapy'].toString()) / 10000000.0;
        final lng = int.parse(e['mapx'].toString()) / 10000000.0;
        return NaverLocalSearchResult(
          title: title,
          address: e['address'] ?? '',
          roadAddress: e['roadAddress'] ?? '',
          lat: lat,
          lng: lng,
        );
      }).toList();
    } catch (e) {
      _logger.e('[장소검색] 오류: $e');
      return [];
    }
  }

  Future<List<NaverLocalSearchResult>> _searchGeocoding(String query) async {
    try {
      final uri = Uri.parse(_geocodingUrl).replace(queryParameters: {
        'query': query,
      });
      final res = await http.get(uri, headers: {
        'X-NCP-APIGW-API-KEY-ID': dotenv.env['NAVER_GEOCODING_CLIENT_ID']!,
        'X-NCP-APIGW-API-KEY': dotenv.env['NAVER_GEOCODING_CLIENT_SECRET']!,
      });
      if (res.statusCode != 200) return [];

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final addresses = data['addresses'] as List? ?? [];
      return addresses.map((e) {
        final roadAddress = (e['roadAddress'] ?? '').toString();
        final jibunAddress = (e['jibunAddress'] ?? '').toString();
        return NaverLocalSearchResult(
          title: roadAddress.isNotEmpty ? roadAddress : jibunAddress,
          address: jibunAddress,
          roadAddress: roadAddress,
          lat: double.parse(e['y'].toString()),
          lng: double.parse(e['x'].toString()),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
