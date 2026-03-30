import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/state/secure_storage.dart';
import 'package:unimal/utils/custom_alert.dart';

/// 모든 API 요청의 공통 진입점.
/// 401 응답 시 자동으로 토큰을 재발급하고 동일 요청을 1회 재시도한다.
/// 재발급도 실패하면 경고창을 띄우고 /login 으로 이동시킨다.
class ApiClient {
  static final _logger = Logger();
  static final _secureStorage = SecureStorage();
  static final _customAlert = CustomAlert();

  // ── 토큰 재발급 ─────────────────────────────────────────────────────
  /// 재발급 성공 → 새 accessToken 반환
  /// 재발급 실패 → 경고창 + /login 이동 후 null 반환
  static Future<String?> _refresh() async {
    final success = await AccountService().tokenReIssue();
    if (!success) {
      _customAlert.pageMovingWithshowTextAlert(
        '인증 만료',
        '로그인이 만료되었습니다.\n다시 로그인해주세요.',
        '/login',
      );
      return null;
    }
    return await _secureStorage.getAccessToken();
  }

  // ── GET ─────────────────────────────────────────────────────────────
  static Future<http.Response> get(
    Uri url,
    Map<String, String> headers,
  ) async {
    var res = await http.get(url, headers: headers);
    if (res.statusCode == 401) {
      final newToken = await _refresh();
      if (newToken == null) return res;
      headers['Authorization'] = 'Bearer $newToken';
      res = await http.get(url, headers: headers);
    }
    return res;
  }

  // ── POST ────────────────────────────────────────────────────────────
  static Future<http.Response> post(
    Uri url,
    Map<String, String> headers, {
    Object? body,
  }) async {
    var res = await http.post(url, headers: headers, body: body);
    if (res.statusCode == 401) {
      final newToken = await _refresh();
      if (newToken == null) return res;
      headers['Authorization'] = 'Bearer $newToken';
      res = await http.post(url, headers: headers, body: body);
    }
    return res;
  }

  // ── PATCH ───────────────────────────────────────────────────────────
  static Future<http.Response> patch(
    Uri url,
    Map<String, String> headers, {
    Object? body,
  }) async {
    var res = await http.patch(url, headers: headers, body: body);
    if (res.statusCode == 401) {
      final newToken = await _refresh();
      if (newToken == null) return res;
      headers['Authorization'] = 'Bearer $newToken';
      res = await http.patch(url, headers: headers, body: body);
    }
    return res;
  }

  // ── DELETE ──────────────────────────────────────────────────────────
  static Future<http.Response> delete(
    Uri url,
    Map<String, String> headers,
  ) async {
    var res = await http.delete(url, headers: headers);
    if (res.statusCode == 401) {
      final newToken = await _refresh();
      if (newToken == null) return res;
      headers['Authorization'] = 'Bearer $newToken';
      res = await http.delete(url, headers: headers);
    }
    return res;
  }

  // ── Multipart ───────────────────────────────────────────────────────
  /// [builder]: 토큰을 받아 MultipartRequest를 비동기로 생성하는 함수.
  /// 401 시 토큰을 재발급받아 builder를 다시 호출해 재시도한다.
  static Future<http.Response> multipart(
    Future<http.MultipartRequest> Function(String token) builder,
    String currentToken,
  ) async {
    var req = await builder(currentToken);
    var streamed = await req.send();
    var res = await http.Response.fromStream(streamed);

    if (res.statusCode == 401) {
      final newToken = await _refresh();
      if (newToken == null) return res;
      req = await builder(newToken);
      streamed = await req.send();
      res = await http.Response.fromStream(streamed);
    }
    return res;
  }

  // ── 외부에서 직접 토큰 재발급이 필요할 때 ────────────────────────────
  static Future<String?> refreshToken() => _refresh();
}
