import 'dart:io';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk_talk.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/screens/widget/alert/custom_alert.dart';

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
      var host = Platform.isAndroid ? dotenv.env['ANDORID_SERVER'] : dotenv.env['IOS_SERVER'];
      var url = Uri.http(host.toString(), 'user/auth/login/mobile/kakao');
      var headers = {
        "Authorization": "Bearer ${token.accessToken}",
        "Content-Type": "application/json; charset=utf-8",
      };
      var res = await http.get(url, headers: headers);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));

      if (bodyData['code'] == 200) {
        final accountService = AccountService();
        var accessToken = res.headers['x-unimal-access-token'].toString();
        var refreshToken = res.headers['x-unimal-refresh-token'].toString();
        var email = res.headers['x-unimal-email'].toString();
        accountService.login(accessToken, refreshToken, email, LoginType.kakao);
        
        Get.offAllNamed("/map");
      } else if (bodyData['code'] == 1009) {
        // 번호 인증 페이지로 이동
        Get.toNamed("/tel-verification", arguments: {
          'email': bodyData["data"],
        });
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
