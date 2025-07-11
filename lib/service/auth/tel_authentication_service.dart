
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class TelAuthenticationService {
  var logger = Logger();

  Future<bool> sendVerificationCode(String tel) async {
    var host = Platform.isAndroid ? dotenv.env['ANDORID_SERVER'] : dotenv.env['IOS_SERVER'];
    var headers = {"Content-Type": "application/json;charset=utf-8"};
    var body = jsonEncode({
              "tel": tel
            });

    var url = Uri.http(host.toString(), '/user/auth/tel/code-request');    

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
}