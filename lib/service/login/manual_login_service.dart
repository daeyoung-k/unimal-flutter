import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/widget/alert/custom_alert.dart';

class ManualLoginService {
  var logger = Logger();

  Future<void> login(String email, String password) async {
    final customAlert = CustomAlert();   

    var body = jsonEncode({
      "email": email,
      "password": password
    });

    try {
      var host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      var headers = {"Content-Type": "application/json;charset=utf-8"};
      var url = Uri.http('${host}:8080', 'user/auth/login/manual');
      var res = await http.post(url, headers: headers, body: body);

      var bodyData = jsonDecode(res.body);

      if (bodyData['code'] == 200) {
        final authState = Get.find<AuthState>();
        await authState.setTokens(            
          res.headers['x-unimal-access-token'].toString(),
          res.headers['x-unimal-refresh-token'].toString(),
          res.headers['x-unimal-email'].toString(),
          LoginType.manual,
        );
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