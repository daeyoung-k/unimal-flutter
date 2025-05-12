import 'dart:io';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk_talk.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/state/auth_state.dart';

class KakaoLoginService {
  Future<void> kakaoInit() async {
    await dotenv.load(fileName: ".env");
    KakaoSdk.init(
      nativeAppKey: dotenv.env['KAKAO_APP_KEY'],
    );
  }

  Future<void> login() async {
    try {
      OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
      var host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      var url = Uri.http('${host}:8080', 'user/auth/login/mobile/kakao');
      var headers = {"Authorization": "Bearer ${token.accessToken}"};
      var res = await http.get(url, headers: headers);
      var bodyData = jsonDecode(res.body);

      if (bodyData['code'] == 200) {
        final authState = Get.find<AuthState>();
        authState.setTokens(            
          res.headers['x-unimal-access-token'].toString(),
          res.headers['x-unimal-refresh-token'].toString(),
          "KAKAO"
        );
        Get.offAllNamed("/map");
      } else {
        print("카카오 로그인 실패 ${bodyData['message']}");
      }
    } catch (error) {
      print('카카오톡으로 로그인 실패 $error');
    }
  }
}
