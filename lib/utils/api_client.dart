import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/state/secure_storage.dart';
import 'package:unimal/utils/custom_alert.dart';

enum AuthFailurePolicy { interactive, silent }

/// 모든 API 요청의 공통 진입점.
/// 401 응답 시 자동으로 토큰을 재발급하고 동일 요청을 1회 재시도한다.
/// 핵심 API는 refresh token 만료 시 경고창을 띄우고 /login 으로 이동시킨다.
/// 부가 API는 silent 정책으로 재발급만 시도하고 화면 이동은 하지 않는다.
class ApiClient {
  static final _secureStorage = SecureStorage();
  static final _customAlert = CustomAlert();

  // 동시에 여러 401이 와도 재발급은 1회만 실행 — 나머지는 완료를 기다린 뒤 같은 토큰 사용
  static Completer<TokenReissueResult>? _refreshCompleter;
  static AuthFailurePolicy _currentRefreshPolicy = AuthFailurePolicy.silent;
  static bool _authExpiredHandledForCurrentRefresh = false;

  static bool shouldRefreshForAuthFailure(http.Response response) {
    if (response.statusCode == 401) return true;

    final bodyData = _decodeBody(response);
    if (bodyData is! Map) {
      return _looksLikeExpiredTokenFailure(_bodyText(response));
    }

    final code = bodyData['code'];
    if (code == 401 || code == '401') return true;

    final message = [
      bodyData['message'],
      bodyData['error'],
      bodyData['exception'],
    ].whereType<String>().join(' ');

    return _looksLikeExpiredTokenFailure(message);
  }

  static String _bodyText(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return response.body;
    }
  }

  static dynamic _decodeBody(http.Response response) {
    try {
      return jsonDecode(_bodyText(response));
    } catch (_) {
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return null;
      }
    }
  }

  static bool _looksLikeExpiredTokenFailure(String message) {
    if (message.isEmpty) return false;

    final lower = message.toLowerCase();
    final mentionsToken =
        lower.contains('token') ||
        lower.contains('jwt') ||
        message.contains('토큰');
    final expiredOrRejected =
        lower.contains('expired') ||
        lower.contains('expiredjwtexception') ||
        lower.contains('tokennotfound') ||
        message.contains('만료');

    return mentionsToken && expiredOrRejected;
  }

  // ── 토큰 재발급 ─────────────────────────────────────────────────────
  /// 재발급 성공 → 새 accessToken 반환
  /// refresh token 만료 → interactive 정책에서만 경고창 + /login 이동 후 null 반환
  static Future<String?> _refresh({
    AuthFailurePolicy authFailurePolicy = AuthFailurePolicy.interactive,
  }) async {
    if (_refreshCompleter != null) {
      if (authFailurePolicy == AuthFailurePolicy.interactive) {
        _currentRefreshPolicy = AuthFailurePolicy.interactive;
      }
      return _handleRefreshResult(await _refreshCompleter!.future);
    }

    _currentRefreshPolicy = authFailurePolicy;
    _authExpiredHandledForCurrentRefresh = false;
    final completer = Completer<TokenReissueResult>();
    _refreshCompleter = completer;
    try {
      // 저장된 refresh 토큰이 없거나(미로그인/로그아웃/세션 클리어) 잘못 저장된 "null"이면
      // 재발급할 세션 자체가 없는 것 → tokenReIssue 시도와 "인증 만료" 다이얼로그 없이
      // 조용히 실패한다. (신규 설치/로그아웃 상태의 백그라운드 인증 호출이 401을 받아도
      // 로그인 화면 위에 만료 팝업이 뜨지 않도록)
      final refresh = await _secureStorage.getRefreshToken();
      if (refresh == null || refresh.isEmpty || refresh == 'null') {
        completer.complete(TokenReissueResult.unavailable);
        return null;
      }

      final result = await AccountService().tokenReIssue(
        clearOnAuthExpired: false,
      );
      completer.complete(result);
      return _handleRefreshResult(result);
    } catch (e) {
      // 예외 발생 시 대기 중인 모든 요청이 null을 받고 unblock 되도록 보장
      if (!completer.isCompleted) {
        completer.complete(TokenReissueResult.unavailable);
      }
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  static Future<String?> _handleRefreshResult(TokenReissueResult result) async {
    if (result == TokenReissueResult.success) {
      return _secureStorage.getAccessToken();
    }
    if (result == TokenReissueResult.authExpired &&
        _currentRefreshPolicy == AuthFailurePolicy.interactive &&
        !_authExpiredHandledForCurrentRefresh) {
      _authExpiredHandledForCurrentRefresh = true;
      await _notifyAuthExpired();
    }
    return null;
  }

  /// 세션 만료 처리 — 상태 정리 후 재로그인 유도.
  /// 각 단계를 개별 격리: 이 함수는 _refresh 의 try 안에서도 불리는데,
  /// 여기서 던진 예외가 그 catch 에 삼켜지면 안내도 이동도 없이 "조용히
  /// 죽은 세션"으로 남는다 (2026-07-15 Android — 다이얼로그 미표시 증상).
  /// Get.dialog 가 예외 없이 표시에 실패하는 환경까지 방어 — 호출 후
  /// 실제로 떠 있는지 확인해 안 떠 있으면 로그인 화면으로 강제 이동한다.
  static Future<void> _notifyAuthExpired() async {
    // 이미 로그인 화면(또는 이동 중)이면 중복 안내 생략 — 연속 401 스팸 방지.
    if (Get.currentRoute == '/login') {
      debugPrint('[auth] 세션 만료 — 이미 로그인 화면, 안내 생략');
      return;
    }
    debugPrint('[auth] 세션 만료 — 상태 정리 후 재로그인 유도');
    try {
      await AccountService().stateClear();
    } catch (e) {
      debugPrint('[auth] stateClear 실패(무시하고 진행): $e');
    }
    try {
      _customAlert.pageMovingWithshowTextAlert(
        '인증 만료',
        '로그인이 만료되었습니다.\n다시 로그인해주세요.',
        '/login',
        barrierDismissible: false, // 바깥 탭으로 닫히면 죽은 세션으로 화면에 남는다
      );
      // 다음 프레임 이후에도 다이얼로그가 안 떠 있으면 표시 실패로 간주.
      await Future.delayed(const Duration(milliseconds: 300));
      if (Get.isDialogOpen != true && Get.currentRoute != '/login') {
        debugPrint(
          '[auth] 만료 다이얼로그 미표시 감지 → 로그인 화면 직접 이동 '
          '(currentRoute=${Get.currentRoute})',
        );
        Get.offAllNamed('/login');
      }
    } catch (e) {
      debugPrint('[auth] 만료 안내 실패 → 로그인 화면 직접 이동: $e');
      try {
        Get.offAllNamed('/login');
      } catch (e2) {
        debugPrint('[auth] 로그인 화면 이동 실패: $e2');
      }
    }
  }

  // ── GET ─────────────────────────────────────────────────────────────
  static Future<http.Response> get(
    Uri url,
    Map<String, String> headers, {
    AuthFailurePolicy authFailurePolicy = AuthFailurePolicy.interactive,
  }) async {
    var res = await http.get(url, headers: headers);
    if (shouldRefreshForAuthFailure(res)) {
      final newToken = await _refresh(authFailurePolicy: authFailurePolicy);
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
    AuthFailurePolicy authFailurePolicy = AuthFailurePolicy.interactive,
  }) async {
    var res = await http.post(url, headers: headers, body: body);
    if (shouldRefreshForAuthFailure(res)) {
      final newToken = await _refresh(authFailurePolicy: authFailurePolicy);
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
    AuthFailurePolicy authFailurePolicy = AuthFailurePolicy.interactive,
  }) async {
    var res = await http.patch(url, headers: headers, body: body);
    if (shouldRefreshForAuthFailure(res)) {
      final newToken = await _refresh(authFailurePolicy: authFailurePolicy);
      if (newToken == null) return res;
      headers['Authorization'] = 'Bearer $newToken';
      res = await http.patch(url, headers: headers, body: body);
    }
    return res;
  }

  // ── DELETE ──────────────────────────────────────────────────────────
  static Future<http.Response> delete(
    Uri url,
    Map<String, String> headers, {
    AuthFailurePolicy authFailurePolicy = AuthFailurePolicy.interactive,
  }) async {
    var res = await http.delete(url, headers: headers);
    if (shouldRefreshForAuthFailure(res)) {
      final newToken = await _refresh(authFailurePolicy: authFailurePolicy);
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
    String currentToken, {
    AuthFailurePolicy authFailurePolicy = AuthFailurePolicy.interactive,
  }) async {
    var req = await builder(currentToken);
    var streamed = await req.send();
    var res = await http.Response.fromStream(streamed);

    if (shouldRefreshForAuthFailure(res)) {
      final newToken = await _refresh(authFailurePolicy: authFailurePolicy);
      if (newToken == null) return res;
      req = await builder(newToken);
      streamed = await req.send();
      res = await http.Response.fromStream(streamed);
    }
    return res;
  }

  // ── 외부에서 직접 토큰 재발급이 필요할 때 ────────────────────────────
  static Future<String?> refreshToken({
    AuthFailurePolicy authFailurePolicy = AuthFailurePolicy.interactive,
  }) => _refresh(authFailurePolicy: authFailurePolicy);
}
