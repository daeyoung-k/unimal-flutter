import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/service/user/model/signup_models.dart';
import 'package:unimal/service/user/model/user_info_model.dart';
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

  Future<UserInfoModel?> getMemberInfo(String accessToken) async {
    var url = ApiUri.resolve('/user/member/info');
    var authHeaders = {"Authorization": "Bearer $accessToken"};

    try {
      var res = await http.get(url, headers: authHeaders);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      if (bodyData['code'] == 200) {
        return UserInfoModel.fromJson(bodyData['data']);
      } else {
        logger.e("내 정보 조회 실패.. ${bodyData['message']}");
        if (bodyData['code'] == 401 || res.statusCode == 401) {
          await AccountService().logout();
        }
        return null;
      }
    } catch (error) {
      logger.e("내 정보 조회 실패.. ${error.toString()}");
      await AccountService().logout();
      return null;
    }
  }

  Future<bool> updateMemberInfo({
    required String accessToken,
    required String nickname,
    required String introduction,
  }) async {
    var url = ApiUri.resolve('/user/member/info/update');
    var authHeaders = {
      "Content-Type": "application/json;charset=utf-8",
      "Authorization": "Bearer $accessToken",
    };
    var body = jsonEncode({
      "nickname": nickname,
      "introduction": introduction,
    });

    try {
      var res = await http.patch(url, headers: authHeaders, body: body);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      if (bodyData['code'] == 200) {
        return true;
      } else {
        logger.e("정보 업데이트 실패.. ${bodyData['message']}");
        return false;
      }
    } catch (error) {
      logger.e("정보 업데이트 실패.. ${error.toString()}");
      return false;
    }
  }

  Future<bool> uploadProfileImage({
    required String accessToken,
    required File imageFile,
  }) async {
    var url = ApiUri.resolve('/user/member/profile/image/upload');
    var request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    try {
      final streamedResponse = await request.send();
      final res = await http.Response.fromStream(streamedResponse);
      final bodyData = jsonDecode(utf8.decode(res.bodyBytes));
      if (bodyData['code'] == 200) {
        return true;
      } else {
        logger.e("프로필 이미지 업로드 실패.. ${bodyData['message']}");
        return false;
      }
    } catch (error) {
      logger.e("프로필 이미지 업로드 실패.. ${error.toString()}");
      return false;
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
