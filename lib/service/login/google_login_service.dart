import 'dart:io';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/widget/alert/custom_alert.dart';

class GoogleLoginService {  
  var logger = Logger();  

  Future<void> login() async {
    final customAlert = CustomAlert(); 
    try {
      var response = await _googleSignIn.signIn();
      var body = jsonEncode({
              "provider": "GOOGLE",
              "email": response!.email,
              "name": response.displayName
            });
      
      var host = Platform.isAndroid ? dotenv.env['ANDORID_SERVER'] : dotenv.env['IOS_SERVER'];
      var headers = {"Content-Type": "application/json;charset=utf-8"};
      var url = Uri.http(host.toString(), 'user/auth/login/mobile/google');
      var res = await http.post(url, headers: headers, body: body);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      
      if (bodyData['code'] == 200) {
        final accountService = AccountService();
        var accessToken = res.headers['x-unimal-access-token'].toString();
        var refreshToken = res.headers['x-unimal-refresh-token'].toString();
        var email = res.headers['x-unimal-email'].toString();
        accountService.login(accessToken, refreshToken, email, LoginType.google);

        Get.offAllNamed("/map");
      } else if (bodyData['code'] == 1009) {
        // 번호 인증 페이지로 이동
        Get.toNamed("/tel-verification", arguments: {
          'email': bodyData["data"],
        });
      } else {
        logger.e("구글 로그인 실패.. code: ${bodyData['code']} message: ${bodyData['message']}");
        customAlert.showTextAlert("로그인 오류", "구글 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
      }      
      
    } catch (error) {
      logger.e("구글 로그인 오류 - ${error.toString()}");
      customAlert.showTextAlert("로그인 오류", "구글 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");      
    }
  }
}

const List<String> scopes = <String>[
  'email',
  'https://www.googleapis.com/auth/contacts.readonly',
  'https://www.googleapis.com/auth/userinfo.profile',
];

GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: scopes,
);