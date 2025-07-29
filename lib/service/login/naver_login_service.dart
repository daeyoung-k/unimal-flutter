import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/screens/widget/alert/custom_alert.dart';

class NaverLoginService {
  var logger = Logger();

  Future<void> naverInit() async {
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
          "nickname": profile.nickName,
          "profileImage": profile.profileImage
        });

        var host = Platform.isAndroid ? dotenv.env['ANDORID_SERVER'] : dotenv.env['IOS_SERVER'];
        var headers = {"Content-Type": "application/json;charset=utf-8"};
        var url = Uri.http(host.toString(), 'user/auth/login/mobile/naver');
        var res = await http.post(url, headers: headers, body: body);
        var bodyData = jsonDecode(utf8.decode(res.bodyBytes));

        if (bodyData['code'] == 200) {
          final accountService = AccountService();
          var accessToken = res.headers['x-unimal-access-token'].toString();
          var refreshToken = res.headers['x-unimal-refresh-token'].toString();
          var email = res.headers['x-unimal-email'].toString();
          accountService.login(accessToken, refreshToken, email, LoginType.naver);
          
          Get.offAllNamed("/map");
        } else if (bodyData['code'] == 1009) {
          // 번호 인증 페이지로 이동
          Get.toNamed("/tel-verification", arguments: {
            'email': bodyData["data"],
          });
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
