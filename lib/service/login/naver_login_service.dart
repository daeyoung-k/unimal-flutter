import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/widget/alert/custom_alert.dart';

class NaverLoginService {
  var logger = Logger();

  Future<void> naverInit() async {
    await dotenv.load(fileName: ".env");
    NaverLoginSDK.initialize(
      urlScheme: dotenv.env['NAVER_LOGIN_IOS_URL_SCHEME']!,
      clientId: dotenv.env['NAVER_LOGIN_CLIENT_ID']!,
      clientSecret: dotenv.env['NAVER_LOGIN_CLIENT_SECRET']!,
      clientName: dotenv.env['NAVER_LOGIN_CLIENT_NAME']!
    );
  }

  Future<void> login() async {
    final customAlert = CustomAlert();   
    NaverLoginSDK.authenticate(
        callback: OAuthLoginCallback(onSuccess: () {
      NaverLoginSDK.profile(
          callback:
              ProfileCallback(onSuccess: (resultCode, message, response) async {
        final profile = NaverLoginProfile.fromJson(response: response);
        var body = jsonEncode({
          "provider": "NAVER",
          "email": profile.email,
          "name": profile.name,
          "nickname": profile.nickName
        });

        var host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
        var headers = {"Content-Type": "application/json;charset=utf-8"};
        var url = Uri.http('${host}:8080', 'user/auth/login/mobile/naver');
        var res = await http.post(url, headers: headers, body: body);
        var bodyData = jsonDecode(res.body);

        if (bodyData['code'] == 200) {
          final authState = Get.find<AuthState>();
          await authState.setTokens(            
            res.headers['x-unimal-access-token'].toString(),
            res.headers['x-unimal-refresh-token'].toString(),
            LoginType.naver
          );
          Get.offAllNamed("/map");
        } else {
          logger.e("네이버 로그인 실패.. code: ${bodyData['code']} message: ${bodyData['message']}");
          customAlert.showTextAlert("로그인 오류", "네이버 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
        }
      }, onFailure: (httpStatus, message) {
        logger.e("네이버 로그인 프로필 조회 실패.. httpsStatus: $httpStatus, message: $message");
        customAlert.showTextAlert("로그인 오류", "네이버 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
      }, onError: (errorCode, message) {
        logger.e("네이버 로그인 프로필 조회 에러.. message: $message");
        customAlert.showTextAlert("로그인 오류", "네이버 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
      }));
    }, onFailure: (httpStatus, message) {
      logger.e("네이버 로그인 실패.. httpStatus: $httpStatus, message: $message");
      customAlert.showTextAlert("로그인 오류", "네이버 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
    }, onError: (errorCode, message) {
      logger.e("네이버 로그인 에러.. errorCode: $errorCode, message: $message");
      customAlert.showTextAlert("로그인 오류", "네이버 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
    }));
  }
}
