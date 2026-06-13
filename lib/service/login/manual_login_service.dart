import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/utils/api_uri.dart';
import 'package:unimal/utils/custom_alert.dart';

class ManualLoginService {
  var logger = Logger();

  Future<void> login(String email, String password) async {
    final customAlert = CustomAlert();   

    var body = jsonEncode({
      "email": email,
      "password": password
    });

    try {
      var headers = {"Content-Type": "application/json;charset=utf-8"};
      var url = ApiUri.resolve('user/auth/login/manual');
      // 서버가 연결만 받고 무응답이면 await가 영원히 안 끝나 무한 스피너에 빠진다.
      // 타임아웃을 걸면 TimeoutException이 나고 아래 catch가 잡아 스피너가 풀린다.
      var res = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      var bodyData = jsonDecode(res.body);

      if (bodyData['code'] == 200) {
        final accountService = AccountService();
          var accessToken = res.headers['x-unimal-access-token'].toString();
          var refreshToken = res.headers['x-unimal-refresh-token'].toString();
          var email = res.headers['x-unimal-email'].toString();
          final ok = await accountService.login(accessToken, refreshToken, email, LoginType.manual);
          if (!ok) {
            customAlert.showTextAlert("로그인 오류", "로그인 정보를 받지 못했어요.\n잠시 후 다시 시도해주세요.");
            return;
          }

        Get.offAllNamed("/map");
      } else if (bodyData['code'] == 1001) {
        customAlert.showTextAlert("재가입 안내", "탈퇴한 계정입니다.\n재가입 문의는 support@unimal.co.kr 으로 연락해 주세요.");
      } else {
        logger.e("이메일 로그인 실패.. code: ${bodyData['code']} message: ${bodyData['message']}");
        customAlert.showTextAlert("로그인 오류", "이메일 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
      }
    } catch (error) {
      logger.e("이메일 로그인 실패.. ${error.toString()}");
      customAlert.showTextAlert("로그인 오류", "이메일 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
    }
  }
}