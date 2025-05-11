import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:naver_login_sdk/naver_login_sdk.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/state/secure_storage.dart';

class NaverLoginService {
  Future<void> login() async {
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
            final secureStorage = Get.find<SecureStorage>();
            secureStorage.write(
                "accessToken", res.headers['x-unimal-access-token'].toString());
            secureStorage.write(
              "refreshToken", res.headers['x-unimal-refresh-token'].toString());
            Get.offAllNamed("/map");
        } else {
          print("네이버 로그인 실패! ${bodyData['message']}");
        }
      }, onFailure: (httpStatus, message) {
        print("네이버 로그인 프로필 조회 실패.. httpsStatus:$httpStatus, message:$message");
      }, onError: (errorCode, message) {
        print("네이버 로그인 프로필 조회 에러.. message:$message");
      }));
    }, onFailure: (httpStatus, message) {
      print("네이버 로그인 실패.. httpStatus:$httpStatus, message:$message");
    }, onError: (errorCode, message) {
      print("네이버 로그인 에러.. errorCode:$errorCode, message:$message");
    }));
  }
}
