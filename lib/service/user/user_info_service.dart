import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;

class UserInfoService {
  var logger = Logger();
  final host = Platform.isAndroid
      ? dotenv.env['ANDORID_SERVER']
      : dotenv.env['IOS_SERVER'];

  final headers = {"Content-Type": "application/json;charset=utf-8"};

  Future<String> changePassword(
      String email, String oldPassword, String newPassword) async {
    var body = jsonEncode({
      "email": email,
      "oldPassword": oldPassword,
      "newPassword": newPassword
    });

    var url = Uri.http(host.toString(), '/user/member/find/change/password');

    try {
      var res = await http.post(url, headers: headers, body: body);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      if (bodyData['code'] == 200) {
        return "ok";
      } else {
        logger.e("비밀번호 변경 실패.. $bodyData");
        return bodyData['message'];
      }
    } catch (error) {
      logger.e("비밀번호 변경 실패.. ${error.toString()}");
      return "비밀번호 변경 실패";
    }
  }

  Future<String> checkNickname(String nickname) async {
    var url = Uri.http(
      host.toString(),
      '/user/member/find/nickname/duplicate',
      {'nickname': nickname},
    );

    try {
      var res = await http.get(url);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      if (bodyData['code'] == 200) {
        return "ok";
      } else {
        return bodyData['message'];
      }
    } catch (error) {
      logger.e("닉네임 중복 체크 실패.. ${error.toString()}");
      return "닉네임 중복 체크 실패\n 잠시 후 다시 시도해주세요.";
    }
  }
}
