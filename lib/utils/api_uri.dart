import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 환경(API_SCHEME, ANDORID_SERVER / IOS_SERVER)에 따라
/// local은 http, 실서버는 https로 한 번에 처리하는 API URI 헬퍼.
///
/// 사용 예:
/// ```dart
/// final url = ApiUri.resolve('user/auth/logout');
/// final url = ApiUri.resolve('/board/post/list', {'page': '1', 'size': '10'});
/// ```
class ApiUri {
  ApiUri._();

  static String get _scheme =>
      dotenv.env['API_SCHEME']?.toLowerCase() ?? 'https';

  static String get _host =>
      (Platform.isAndroid ? dotenv.env['ANDORID_SERVER'] : dotenv.env['IOS_SERVER']) ?? '';

  /// path: 앞에 '/' 있든 없든 동일하게 동작 (내부에서 정규화)
  /// queryParameters: optional
  static Uri resolve(String path, [Map<String, String>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final host = _host;
    final scheme = _scheme;
    if (scheme == 'https') {
      return Uri.https(host, normalizedPath, queryParameters);
    }
    return Uri.http(host, normalizedPath, queryParameters);
  }
}
