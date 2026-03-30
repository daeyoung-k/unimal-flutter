import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/user/model/signup_models.dart';
import 'package:unimal/service/user/model/user_info_model.dart';
import 'package:unimal/state/secure_storage.dart';
import 'package:unimal/utils/api_client.dart';
import 'package:unimal/utils/api_uri.dart';

class UserInfoService {
  final _logger = Logger();
  final _secureStorage = SecureStorage();

  final _jsonHeaders = {"Content-Type": "application/json;charset=utf-8"};

  Future<Map<String, String>> _authHeaders() async {
    final token = await _secureStorage.getAccessToken();
    return {
      'Content-Type': 'application/json;charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── 인증 불필요 메서드들 ────────────────────────────────────────────

  Future<String> changePassword(String email, String oldPassword, String newPassword) async {
    final url = ApiUri.resolve('/user/member/find/change/password');
    final body = jsonEncode({'email': email, 'oldPassword': oldPassword, 'newPassword': newPassword});
    try {
      final res = await http.post(url, headers: _jsonHeaders, body: body);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data['code'] == 200) return 'ok';
      _logger.e('비밀번호 변경 실패: $data');
      return data['message'];
    } catch (e) {
      _logger.e('비밀번호 변경 실패: $e');
      return '비밀번호 변경 실패';
    }
  }

  Future<String> checkNickname(String nickname) async {
    final url = ApiUri.resolve('/user/member/find/nickname/duplicate', {'nickname': nickname});
    try {
      final res = await http.get(url);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data['code'] == 200) return 'ok';
      return data['message'];
    } catch (e) {
      _logger.e('닉네임 중복 체크 실패: $e');
      return '닉네임 중복 체크 실패\n잠시 후 다시 시도해주세요.';
    }
  }

  Future<String> checkEmail(String email) async {
    final url = ApiUri.resolve('/user/member/find/email/duplicate');
    final body = jsonEncode({'email': email});
    try {
      final res = await http.post(url, headers: _jsonHeaders, body: body);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data['code'] == 200) return 'ok';
      return data['message'];
    } catch (e) {
      _logger.e('이메일 인증요청 실패: $e');
      return '이메일 인증요청 실패\n잠시 후 다시 시도해주세요.';
    }
  }

  Future<String> checkTel(String tel) async {
    final url = ApiUri.resolve('/user/member/find/tel/duplicate');
    final body = jsonEncode({'tel': tel});
    try {
      final res = await http.post(url, headers: _jsonHeaders, body: body);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data['code'] == 200) return 'ok';
      return data['message'];
    } catch (e) {
      _logger.e('전화번호 인증요청 실패: $e');
      return '전화번호 인증요청 실패\n잠시 후 다시 시도해주세요.';
    }
  }

  Future<String> signup(SignupModel signupModel) async {
    final url = ApiUri.resolve('/user/auth/signup/manual');
    final body = jsonEncode(signupModel.toJson());
    try {
      final res = await http.post(url, headers: _jsonHeaders, body: body);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data['code'] == 200) {
        await AccountService().stateClear();
        return 'ok';
      }
      return data['message'];
    } catch (e) {
      _logger.e('회원가입 실패: $e');
      return '회원가입 실패\n잠시 후 다시 시도해주세요.';
    }
  }

  // ── 인증 필요 메서드들 (ApiClient 사용) ────────────────────────────

  Future<UserInfoModel?> getMemberInfo(String accessToken) async {
    final url = ApiUri.resolve('/user/member/info');
    final headers = {'Authorization': 'Bearer $accessToken'};
    final response = await ApiClient.get(url, headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['code'] == 200) return UserInfoModel.fromJson(data['data']);
    }

    _logger.e('내 정보 조회 실패: ${response.statusCode}');
    return null;
  }

  Future<bool> updateMemberInfo({
    required String accessToken,
    required String nickname,
    required String introduction,
  }) async {
    final url = ApiUri.resolve('/user/member/info/update');
    final headers = await _authHeaders();
    final body = jsonEncode({'nickname': nickname, 'introduction': introduction});

    final response = await ApiClient.patch(url, headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['code'] == 200) return true;
    }

    _logger.e('정보 업데이트 실패: ${response.statusCode}');
    return false;
  }

  Future<bool> updatePersonalInfo({
    required String accessToken,
    required String name,
    required String nickname,
    required String tel,
    required String introduction,
    required String birthday,
    required String gender,
  }) async {
    final url = ApiUri.resolve('/user/member/info/update');
    final headers = await _authHeaders();
    final body = jsonEncode({
      'name': name,
      'nickname': nickname,
      'tel': tel,
      'introduction': introduction,
      'birthday': birthday,
      'gender': gender,
    });

    final response = await ApiClient.patch(url, headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['code'] == 200) return true;
    }

    _logger.e('개인정보 업데이트 실패: ${response.statusCode}');
    return false;
  }

  Future<bool> uploadProfileImage({
    required String accessToken,
    required File imageFile,
  }) async {
    final url = ApiUri.resolve('/user/member/profile/image/upload');

    Future<http.MultipartRequest> buildRequest(String token) async {
      return http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }

    final token = await _secureStorage.getAccessToken() ?? accessToken;
    final response = await ApiClient.multipart(buildRequest, token);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['code'] == 200) return true;
    }

    _logger.e('프로필 이미지 업로드 실패: ${response.statusCode}');
    return false;
  }

  Future<String> sendTelVerificationCode(String accessToken, String email, String tel) async {
    final url = ApiUri.resolve('/user/auth/email-tel/code-request');
    final headers = await _authHeaders();
    final body = jsonEncode({'email': email, 'tel': tel});

    final response = await ApiClient.post(url, headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['code'] == 200) return 'ok';
      return data['message'] ?? '인증코드 발송 실패';
    }

    _logger.e('전화번호 인증코드 발송 실패: ${response.statusCode}');
    return '인증코드 발송 실패. 잠시 후 다시 시도해주세요.';
  }

  Future<Map<String, String>?> verifyAndUpdateTel(
    String accessToken,
    String code,
    String email,
    String tel,
  ) async {
    final url = ApiUri.resolve('/user/auth/tel/check-update');
    final headers = await _authHeaders();
    final body = jsonEncode({'code': code, 'email': email, 'tel': tel});

    final response = await ApiClient.post(url, headers, body: body);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['code'] == 200) {
        return {
          'email': response.headers['x-unimal-email'] ?? '',
          'accessToken': response.headers['x-unimal-access-token'] ?? '',
          'refreshToken': response.headers['x-unimal-refresh-token'] ?? '',
        };
      }
      return {'error': data['message'] ?? '인증에 실패했습니다.'};
    }

    _logger.e('전화번호 변경 인증 실패: ${response.statusCode}');
    return {'error': '인증에 실패했습니다. 잠시 후 다시 시도해주세요.'};
  }

  Future<void> updateDeviceInfo(Map<String, dynamic> deviceInfo) async {
    final url = ApiUri.resolve('/user/member/device/info/update');
    final headers = await _authHeaders();
    final body = jsonEncode(deviceInfo);
    try {
      await ApiClient.post(url, headers, body: body);
    } catch (e) {
      _logger.e('디바이스 정보 업데이트 실패: $e');
    }
  }
}
