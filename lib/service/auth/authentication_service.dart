import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:unimal/screens/auth/dto/find_email.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/login/login_type.dart';

class AuthenticationCodeService {
  var logger = Logger();
  final host = Platform.isAndroid
      ? dotenv.env['ANDORID_SERVER']
      : dotenv.env['IOS_SERVER'];
  final headers = {"Content-Type": "application/json;charset=utf-8"};

  Future<bool> sendEmailTelVerificationCode(String email, String tel) async {
    var body = jsonEncode({"email": email, "tel": tel});

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
    var body = jsonEncode({"email": email, "tel": tel, "code": code});

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

  Future<String> verifyEmailTelVerificationCodeAndTelUpdate(
      String email, String tel, String code) async {
    var body = jsonEncode({"email": email, "tel": tel, "code": code});

    var url = Uri.http(host.toString(), '/user/auth/tel/check-update');
    try {
      var res = await http.post(url, headers: headers, body: body);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      if (bodyData['code'] == 200) {
        final accountService = AccountService();
        var loginType =
            LoginType.from(res.headers['x-unimal-provider'].toString());
        var accessToken = res.headers['x-unimal-access-token'].toString();
        var refreshToken = res.headers['x-unimal-refresh-token'].toString();
        var email = res.headers['x-unimal-email'].toString();
        accountService.login(accessToken, refreshToken, email, loginType);

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

  Future<bool> sendTelVerificationCode(String tel) async {
    var body = jsonEncode({
      "tel": tel,
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

  Future<FindEmail> verifyTelVerificationCodeIdFind(
      String tel, String code) async {
    var body = jsonEncode({"tel": tel, "code": code});

    var url = Uri.http(host.toString(), '/user/member/find/email');
    try {
      var res = await http.post(url, headers: headers, body: body);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      if (bodyData['code'] == 200) {
        var data = bodyData['data'];

        var result = FindEmail(
          email: data['email'],
          isSuccess: data['email'] != null ? true : false,
          message: data['message'],
        );

        return result;
      } else {
        logger.e("아이디 찾기 실패.. $bodyData");
        return FindEmail();
      }
    } catch (error) {
      logger.e("아이디 찾기 실패.. ${error.toString()}");
      return FindEmail();
    }
  }
}
