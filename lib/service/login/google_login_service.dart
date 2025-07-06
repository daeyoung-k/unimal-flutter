import 'dart:io';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
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
      
      var host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
      var headers = {"Content-Type": "application/json;charset=utf-8"};
      var url = Uri.http('${host}:8080', 'user/auth/login/mobile/google');
      var res = await http.post(url, headers: headers, body: body);
      var bodyData = jsonDecode(res.body);
      
      if (bodyData['code'] == 200) {
        final authState = Get.find<AuthState>();
        await authState.setTokens(            
          res.headers['x-unimal-access-token'].toString(),
          res.headers['x-unimal-refresh-token'].toString(),
          res.headers['x-unimal-email'].toString(),
          LoginType.google,
        );
        Get.offAllNamed("/map");
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