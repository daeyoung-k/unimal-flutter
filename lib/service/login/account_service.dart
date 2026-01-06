import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:logger/logger.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/state/auth_state.dart';

class AccountService {
  var logger = Logger();

  final _authState = Get.find<AuthState>();

  var host = Platform.isAndroid
      ? dotenv.env['ANDORID_SERVER']
      : dotenv.env['IOS_SERVER'];

  Future<void> login(
    String accessToken,
    String refreshToken,
    String email,
    LoginType loginType,
  ) async {
    await _authState.setTokens(accessToken, refreshToken, email, loginType);
  }

  Future<void> logout() async {
    var url = Uri.http(host.toString(), 'user/auth/logout');
    var headers = {"Authorization": "Bearer ${_authState.refreshToken}"};
    await http.get(url, headers: headers);

    await _authStateClear();

    Get.offAllNamed("/login");
  }

  Future<void> withdrawal() async {
    var url = Uri.http(host.toString(), 'user/auth/withdrawal');
    var headers = {"Authorization": "Bearer ${_authState.refreshToken}"};
    await http.get(url, headers: headers);

    await _authStateClear();

    Get.offAllNamed("/login");
  }

  Future<bool> tokenReIssue() async {
    var url = Uri.http(host.toString(), '/user/auth/token-reissue');
    var headers = {"Authorization": "Bearer ${_authState.refreshToken}"};
    try {
      var res = await http.get(url, headers: headers);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      if (bodyData['code'] == 200) {
        await _authState.setTokens(
          res.headers['x-unimal-access-token'].toString(),
          res.headers['x-unimal-refresh-token'].toString(),
          res.headers['x-unimal-email'].toString(),
          _authState.provider.value,
        );
        return true;
      } else {
        stateClear();
        logger.e("토큰 재발급 실패.. ${bodyData['message']}");
        return false;
      }
    } catch (error) {
      stateClear();
      logger.e("토큰 재발급 실패.. ${error.toString()}");
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
        print("일반 로그인 타입 로그아웃");
        break;
      case LoginType.none:
        print("로그인 상태가 아닙니다.");
        break;
    }

    await _authState.clearTokens();
  }

  _naverLogout() async {
    await NaverLoginSDK.release(callback: OAuthLoginCallback(onSuccess: () {}));
  }

  _kakaoLogout() async {
    await UserApi.instance.logout();
  }

  _googleLogout() async {
    await GoogleSignIn().signOut();
  }
}
