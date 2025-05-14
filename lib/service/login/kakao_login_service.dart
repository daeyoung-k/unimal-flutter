import 'dart:io';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk_talk.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/widget/alert/custom_alert.dart';

class KakaoLoginService {
  var logger = Logger();  

  Future<void> kakaoInit() async {
    KakaoSdk.init(
      nativeAppKey: dotenv.env['KAKAO_APP_KEY'],
    );
  }

  Future<void> login() async {
    final customAlert = CustomAlert();  
    try {
      OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
      var host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      var url = Uri.http('${host}:8080', 'user/auth/login/mobile/kakao');
      var headers = {"Authorization": "Bearer ${token.accessToken}"};
      var res = await http.get(url, headers: headers);
      var bodyData = jsonDecode(res.body);

      if (bodyData['code'] == 200) {
        final authState = Get.find<AuthState>();
        await authState.setTokens(            
          res.headers['x-unimal-access-token'].toString(),
          res.headers['x-unimal-refresh-token'].toString(),
          LoginType.kakao
        );
        Get.offAllNamed("/map");
      } else {
        logger.e("카카오 로그인 실패.. code: ${bodyData['code']} message: ${bodyData['message']}");
        customAlert.showTextAlert("로그인 오류", "카카오 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
      }
    } catch (error) {
      logger.e('카카오 로그인 실패.. ${error.toString()}');
      customAlert.showTextAlert("로그인 오류", "카카오 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
    }
  }
}
