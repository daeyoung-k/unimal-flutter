
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class AuthenticationCodeService {
  var logger = Logger();

  Future<bool> sendEmailTelVerificationCode(String email, String tel) async {
    var host = Platform.isAndroid ? dotenv.env['ANDORID_SERVER'] : dotenv.env['IOS_SERVER'];
    var headers = {"Content-Type": "application/json;charset=utf-8"};
    var body = jsonEncode({
              "email": email,
              "tel": tel
            });

    var url = Uri.http(host.toString(), '/user/auth/email-tel/code-request');    

    try {
      var res = await http.post(url, headers: headers, body: body);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));      
      if (bodyData['code'] == 200) {
        return true;
      } else {
        logger.e("인증번호 전송 실패.. $bodyData");
        return false;
      }
    } catch (error) {
      logger.e("인증번호 전송 실패.. ${error.toString()}");
      return false;
    }
  }

  Future<String> verifyEmailTelVerificationCode(String email, String tel, String code) async {
    var host = Platform.isAndroid ? dotenv.env['ANDORID_SERVER'] : dotenv.env['IOS_SERVER'];
    var headers = {"Content-Type": "application/json;charset=utf-8"};
    var body = jsonEncode({
                "email": email,
                "tel": tel,
                "code": code
            });

    var url = Uri.http(host.toString(), '/user/auth/email-tel/code-verify');
    try {
      var res = await http.post(url, headers: headers, body: body);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));      
      if (bodyData['code'] == 200) {
        return "ok";
      } else {
        logger.e("인증번호 인증 실패.. $bodyData");
        return bodyData['message'];
      }
    } catch (error) {
      logger.e("인증번호 인증 실패.. ${error.toString()}");
      return "인증번호 인증에 실패했습니다.";
    }
  }
}