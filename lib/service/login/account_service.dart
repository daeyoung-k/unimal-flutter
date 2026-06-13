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
    LoginType loginType,
  ) async {
    if (accessToken.isEmpty ||
        accessToken == 'null' ||
        refreshToken.isEmpty ||
        refreshToken == 'null') {
      logger.e('로그인 실패: 응답에 토큰이 없습니다. (저장 취소)');
      return false;
    }
    await _authState.setTokens(accessToken, refreshToken, email, loginType);
    final simpleDeviceInfo = await DeviceInfoService().getSimpleDeviceInfo();
    await UserInfoService().updateDeviceInfo(simpleDeviceInfo);
    return true;
  }

  Future<void> logout() async {
    var url = ApiUri.resolve('user/auth/logout');
    var headers = {"Authorization": "Bearer ${_authState.refreshToken}"};
    await http.get(url, headers: headers);

    await _authStateClear();

    Get.offAllNamed("/login");
  }

  Future<void> withdrawal() async {
    var url = ApiUri.resolve('user/auth/withdrawal');
    var headers = {"Authorization": "Bearer ${_authState.refreshToken}"};
    await http.get(url, headers: headers);

    await _authStateClear();

    Get.offAllNamed("/login");
  }

  Future<bool> tokenReIssue() async {
    var url = ApiUri.resolve('/user/auth/token-reissue');
    var headers = {"Authorization": "Bearer ${_authState.refreshToken}"};
    try {
      var res = await http.get(url, headers: headers);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      if (bodyData['code'] == 200) {
        final newAccess = res.headers['x-unimal-access-token'];
        final newRefresh = res.headers['x-unimal-refresh-token'];
        // 재발급 응답에 토큰 헤더가 없으면 "null" 저장 대신 실패 처리.
        if (newAccess == null || newAccess.isEmpty || newAccess == 'null' ||
            newRefresh == null || newRefresh.isEmpty || newRefresh == 'null') {
          stateClear();
          return false;
        }
        await _authState.setTokens(
          newAccess,
          newRefresh,
          res.headers['x-unimal-email'] ?? '',
          _authState.provider.value,
        );
        return true;
      } else {
        stateClear();
        return false;
      }
    } catch (error) {
      stateClear();
      return false;
    }
  }

  Future<void> stateClear() async {
    await _authStateClear();
  }

  Future<void> _authStateClear() async {
    switch (_authState.provider.value) {
      case LoginType.naver:
        await _naverLogout();
        break;
      case LoginType.kakao:
        await _kakaoLogout();
        break;
      case LoginType.google:
        await _googleLogout();
        break;
      case LoginType.manual:
        break;
      case LoginType.none:
        break;
    }

    await _authState.clearTokens();
  }

  _naverLogout() async {
    try {
      await NaverLoginSDK.release(callback: OAuthLoginCallback(onSuccess: () {}));
    } catch (e) {
      logger.w("네이버 로그아웃 실패 (무시): $e");
    }
  }

  _kakaoLogout() async {
    try {
      await UserApi.instance.logout();
    } catch (e) {
      // 토큰이 이미 만료/삭제된 경우 무시하고 로컬 상태 초기화 진행
      logger.w("카카오 로그아웃 실패 (무시): $e");
    }
  }

  _googleLogout() async {
    try {
      await googleSignIn.signOut();
    } catch (e) {
      logger.w("구글 로그아웃 실패 (무시): $e");
    }
  }
}
