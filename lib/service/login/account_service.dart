import 'dart:io';

import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/state/auth_state.dart';

class AccountService {
  final _authState = Get.find<AuthState>();

  Future<void> logout() async {
    var host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    var url = Uri.http('${host}:8080', 'user/auth/logout');
    var headers = {"Authorization": "Bearer ${_authState.refreshToken}"};
    await http.get(url, headers: headers);

    await _authStateClear();

    Get.offAllNamed("/login");
  }

  Future<void> withdrawal() async {
    var host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    var url = Uri.http('${host}:8080', 'user/auth/withdrawal');
    var headers = {"Authorization": "Bearer ${_authState.refreshToken}"};
    await http.get(url, headers: headers);

    await _authStateClear();

    Get.offAllNamed("/login");
  }

  _authStateClear() async {
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
