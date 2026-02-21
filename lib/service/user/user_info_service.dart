import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/service/user/model/signup_models.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/state/secure_storage.dart';
import 'package:unimal/utils/api_uri.dart';

class UserInfoService {
  var logger = Logger();
  final SecureStorage _secureStorage = SecureStorage();

  final headers = {"Content-Type": "application/json;charset=utf-8"};

  Future<String> changePassword(
    String email,
    String oldPassword,
    String newPassword,
  ) async {
    var body = jsonEncode({
      "email": email,
      "oldPassword": oldPassword,
      "newPassword": newPassword,
    });

    var url = ApiUri.resolve('/user/member/find/change/password');

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
    var url = ApiUri.resolve('/user/member/find/nickname/duplicate', {'nickname': nickname});

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

  Future<String> checkEmail(String email) async {
    var url = ApiUri.resolve('/user/member/find/email/duplicate');
    var body = jsonEncode({"email": email});

    try {
      var res = await http.post(url, headers: headers, body: body);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      if (bodyData['code'] == 200) {
        return "ok";
      } else {
        return bodyData['message'];
      }
    } catch (error) {
      logger.e("이메일 인증요청 실패.. ${error.toString()}");
      return "이메일 인증요청 실패\n 잠시 후 다시 시도해주세요.";
    }
  }

  Future<String> checkTel(String tel) async {
    var url = ApiUri.resolve('/user/member/find/tel/duplicate');
    var body = jsonEncode({"tel": tel});

    try {
      var res = await http.post(url, headers: headers, body: body);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      if (bodyData['code'] == 200) {
        return "ok";
      } else {
        return bodyData['message'];
      }
    } catch (error) {
      logger.e("전화번호 인증요청 실패.. ${error.toString()}");
      return "전화번호 인증요청 실패\n 잠시 후 다시 시도해주세요.";
    }
  }

  Future<String> signup(SignupModel signupModel) async {
    var url = ApiUri.resolve('/user/auth/signup/manual');
    var body = jsonEncode(signupModel.toJson());

    try {
      var res = await http.post(url, headers: headers, body: body);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      if (bodyData['code'] == 200) {
        final accountService = AccountService();
        await accountService.stateClear();
        return "ok";
      } else {
        return bodyData['message'];
      }
    } catch (error) {
      logger.e("전화번호 인증요청 실패.. ${error.toString()}");
      return "전화번호 인증요청 실패\n 잠시 후 다시 시도해주세요.";
    }
  }

  Future<void> updateDeviceInfo(Map<String, dynamic> deviceInfo) async {
    var url = ApiUri.resolve('/user/member/device/info/update');

    String? accessToken = await _secureStorage.getAccessToken();
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }    
    var body = jsonEncode(deviceInfo);
    try {
      await http.post(url, headers: headers, body: body);
    } catch (error) {
      logger.e("디바이스 정보 업데이트 실패.. ${error.toString()}");
    }
  }
}
