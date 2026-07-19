import 'dart:convert';

import 'package:get/get.dart';
import 'package:unimal/service/login/google_login_service.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:logger/logger.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:unimal/service/auth/device_info_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/service/user/user_info_service.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/utils/api_uri.dart';

enum TokenReissueResult {
  success,
  authExpired,
  unavailable,
}

class AccountService {
  var logger = Logger();

  final _authState = Get.find<AuthState>();

  /// 로그인 성공 처리. 토큰 저장 후 기기정보 동기화.
  /// 응답에 토큰이 없어 빈 값/"null"이 넘어오면 저장을 거부하고 false 반환 —
  /// "로그인된 것처럼 보이지만 모든 인증 호출이 실패"하는 깨진 상태를 막는다.
  Future<bool> login(
    String accessToken,
    String refreshToken,
    String email,
    LoginType loginMethod,
  ) async {
    if (accessToken.isEmpty ||
        accessToken == 'null' ||
        refreshToken.isEmpty ||
        refreshToken == 'null') {
      logger.e('로그인 실패: 응답에 토큰이 없습니다. (저장 취소)');
      return false;
    }
    await _authState.setTokens(accessToken, refreshToken, email, loginMethod);
    final simpleDeviceInfo = await DeviceInfoService().getSimpleDeviceInfo();
    await UserInfoService().updateDeviceInfo(simpleDeviceInfo);
    return true;
  }

  /// 로그아웃 — 서버 호출은 best-effort. 서버 hang·네트워크 오류가
  /// 로컬 세션 정리와 화면 전환을 막으면 안 된다 (카카오 SDK hang 과 동일 원칙).
  /// 서버 호출이 실패해도 로컬 refresh 토큰은 지워지고 서버 토큰은 만료로 소멸.
  Future<void> logout() async {
    await _serverSessionEnd('user/auth/logout');

    await _authStateClear();

    Get.offAllNamed("/login");
  }

  /// 탈퇴 — 로그아웃과 달리 서버 처리가 "성공해야만" 로컬 정리로 진행.
  /// 실패를 무시하면 사용자는 탈퇴됐다고 믿는데 계정이 살아있는 상태가 된다.
  /// 실패 시 false 반환 — 호출부(마이페이지)에서 안내 처리.
  Future<bool> withdrawal() async {
    final ok = await _serverSessionEnd('user/auth/withdrawal');
    if (!ok) {
      logger.w('탈퇴 실패: 서버 처리 실패 — 로컬 세션 유지');
      return false;
    }

    await _authStateClear();

    Get.offAllNamed("/login");
    return true;
  }

  /// 서버 세션 종료(로그아웃/탈퇴) 호출. 5초 타임아웃, 예외는 실패로 수렴.
  Future<bool> _serverSessionEnd(String path) async {
    try {
      final url = ApiUri.resolve(path);
      final headers = {"Authorization": "Bearer ${_authState.refreshToken}"};
      final res = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (e) {
      logger.w('서버 세션 종료 실패: $e');
      return false;
    }
  }

  Future<TokenReissueResult> tokenReIssue({bool clearOnAuthExpired = true}) async {
    var url = ApiUri.resolve('/user/auth/token-reissue');
    var headers = {"Authorization": "Bearer ${_authState.refreshToken}"};
    try {
      var res = await http.get(url, headers: headers);
      dynamic bodyData;
      try {
        bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        bodyData = null;
      }
      final responseCode = bodyData is Map ? bodyData['code'] : null;
      logger.i('토큰 재발급 요청 ${res.body}');
      logger.i('토큰 재발급 요청 $responseCode');
      if (res.statusCode == 200 && responseCode == 200) {
        final newAccess = res.headers['x-unimal-access-token'];
        final newRefresh = res.headers['x-unimal-refresh-token'];
        // 재발급 응답에 토큰 헤더가 없으면 "null" 저장 대신 실패 처리.
        if (newAccess == null || newAccess.isEmpty || newAccess == 'null' ||
            newRefresh == null || newRefresh.isEmpty || newRefresh == 'null') {
          logger.w('토큰 재발급 실패: 응답 헤더에 새 토큰이 없습니다.');
          return TokenReissueResult.unavailable;
        }
        await _authState.setTokens(
          newAccess,
          newRefresh,
          res.headers['x-unimal-email'] ?? '',
          _authState.loginMethod.value,
        );
        return TokenReissueResult.success;
      }
      // 재발급 엔드포인트의 4xx 는 전부 "이 refresh 토큰은 못 쓴다"는 뜻
      // (만료·폐기·미존재) → 인증 만료로 처리해 재로그인을 유도한다.
      // 게이트웨이가 TokenNotFoundException 을 401이 아닌 코드로 내려도
      // 재로그인 유도가 누락되지 않게 (2026-07-15 Android — 만료 세션인데
      // 다이얼로그 없이 조용히 실패하던 문제). 5xx/네트워크 오류만 일시
      // 실패(unavailable)로 남긴다.
      final bool refreshRejected = (res.statusCode >= 400 &&
              res.statusCode < 500) ||
          (responseCode is int && responseCode >= 400 && responseCode < 500);
      if (refreshRejected) {
        logger.w('토큰 재발급 거부(인증 만료 처리): '
            'status=${res.statusCode}, code=$responseCode');

        if (clearOnAuthExpired) {
          await stateClear();
        }
        return TokenReissueResult.authExpired;
      }
      logger.w('토큰 재발급 실패: status=${res.statusCode}, code=$responseCode');
      return TokenReissueResult.unavailable;
    } catch (error) {
      logger.w('토큰 재발급 일시 실패: $error');
      return TokenReissueResult.unavailable;
    }
  }

  Future<void> stateClear() async {
    await _authStateClear();
  }

  /// 로컬 세션 정리가 최우선. SDK 로그아웃(카카오/네이버/구글)은
  /// best-effort 로만 시도한다 — 카카오 SDK logout() 이 완료되지 않고
  /// 무한 대기하는 사례가 있어(2026-07-15 Android 로그아웃 hang),
  /// SDK 호출을 블로킹으로 기다리면 토큰 정리·화면 전환까지 전부 막힌다.
  /// 로컬 토큰을 먼저 지우고, SDK 로그아웃은 타임아웃을 걸어 뒤에서 처리.
  Future<void> _authStateClear() async {
    final loginMethod = _authState.loginMethod.value;

    // 1. 로컬 세션부터 즉시 정리 — 이게 실패하면 안 되는 핵심.
    await _authState.clearTokens();

    // 2. SDK 로그아웃은 best-effort. 실패/지연이 흐름을 막지 않도록
    //    await 하지 않고 타임아웃만 걸어 백그라운드로 보낸다.
    _sdkLogoutBestEffort(loginMethod);
  }

  void _sdkLogoutBestEffort(LoginType loginMethod) {
    final Future<void> Function()? sdkLogout = switch (loginMethod) {
      LoginType.naver => _naverLogout,
      LoginType.kakao => _kakaoLogout,
      LoginType.google => _googleLogout,
      LoginType.manual || LoginType.none => null,
    };
    if (sdkLogout == null) return;

    sdkLogout()
        .timeout(const Duration(seconds: 3))
        .catchError((e) => logger.w("SDK 로그아웃 실패/타임아웃 (무시): $e"));
  }

  Future<void> _naverLogout() async {
    await NaverLoginSDK.release(callback: OAuthLoginCallback(onSuccess: () {}));
  }

  Future<void> _kakaoLogout() async {
    // 토큰이 이미 만료/삭제된 경우 예외가 나도 무시 (caller 에서 흡수)
    await UserApi.instance.logout();
  }

  Future<void> _googleLogout() async {
    await googleSignIn.signOut();
  }
}
