import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/screens/widget/alert/custom_alert.dart';

class ManualLoginService {
  var logger = Logger();

  Future<void> login(String email, String password) async {
    final customAlert = CustomAlert();   

    var body = jsonEncode({
      "email": email,
      "password": password
    });

    try {
      var host = Platform.isAndroid ? dotenv.env['ANDORID_SERVER'] : dotenv.env['IOS_SERVER'];
      var headers = {"Content-Type": "application/json;charset=utf-8"};
      var url = Uri.http(host.toString(), 'user/auth/login/manual');
      var res = await http.post(url, headers: headers, body: body);

      var bodyData = jsonDecode(res.body);

      if (bodyData['code'] == 200) {
        final accountService = AccountService();
          var accessToken = res.headers['x-unimal-access-token'].toString();
          var refreshToken = res.headers['x-unimal-refresh-token'].toString();
          var email = res.headers['x-unimal-email'].toString();
          accountService.login(accessToken, refreshToken, email, LoginType.manual);

        Get.offAllNamed("/map");
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