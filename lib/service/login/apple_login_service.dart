import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:unimal/service/login/account_service.dart';
import 'package:unimal/service/login/login_type.dart';
import 'package:unimal/utils/api_uri.dart';
import 'package:unimal/utils/custom_alert.dart';

/// Sign in with Apple.
///
/// 다른 소셜 로그인과 다른 점:
/// - 이메일을 클라이언트가 보내지 않는다. 서버가 identityToken(JWT)을 애플 공개키로
///   검증한 뒤 그 안에서 이메일과 고유 식별자(sub)를 꺼낸다.
/// - 이름(givenName/familyName)은 애플이 "최초 인증 1회"에만 내려준다.
///   이때 서버에 넘기지 못하면 영영 받을 수 없으므로 반드시 같이 전송한다.
/// - authorizationCode는 서버가 refresh_token으로 교환해 보관했다가
///   탈퇴 시 애플 계정 연결 해제(revoke)에 사용한다.
class AppleLoginService {
  var logger = Logger();

  Future<void> login() async {
    final customAlert = CustomAlert();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        logger.e("애플 로그인 실패: identityToken이 없습니다.");
        customAlert.showTextAlert(
            "로그인 오류", "애플 로그인 정보를 받지 못했어요.\n잠시후에 다시 시도 해주세요.");
        return;
      }

      final displayName = _resolveName(credential);

      var body = jsonEncode({
        "identityToken": identityToken,
        "authorizationCode": credential.authorizationCode,
        "name": displayName,
        "nickname": displayName,
      });

      var headers = {"Content-Type": "application/json;charset=utf-8"};
      var url = ApiUri.resolve('user/auth/login/mobile/apple');
      var res = await http.post(url, headers: headers, body: body);
      var bodyData = jsonDecode(utf8.decode(res.bodyBytes));

      if (bodyData['code'] == 200) {
        final accountService = AccountService();
        var accessToken = res.headers['x-unimal-access-token'].toString();
        var refreshToken = res.headers['x-unimal-refresh-token'].toString();
        var email = res.headers['x-unimal-email'].toString();
        final ok = await accountService.login(
            accessToken, refreshToken, email, LoginType.apple);
        if (!ok) {
          customAlert.showTextAlert(
              "로그인 오류", "로그인 정보를 받지 못했어요.\n잠시 후 다시 시도해주세요.");
          return;
        }

        Get.offAllNamed("/map");
      } else if (bodyData['code'] == 1009) {
        // 번호 인증 페이지로 이동
        Get.toNamed("/tel-verification", arguments: {
          'email': bodyData["data"],
        });
      } else if (bodyData['code'] == 1001) {
        customAlert.showTextAlert("재가입 안내",
            "탈퇴한 계정입니다.\n재가입 문의는 support@unimal.co.kr 으로 연락해 주세요.");
      } else {
        logger.e(
            "애플 로그인 실패.. code: ${bodyData['code']} message: ${bodyData['message']}");
        customAlert.showTextAlert(
            "로그인 오류", "애플 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      // 사용자가 시트를 닫은 경우는 오류가 아니다 — 조용히 종료.
      if (e.code == AuthorizationErrorCode.canceled) return;
      logger.e("애플 로그인 오류 - ${e.code} ${e.message}");
      customAlert.showTextAlert(
          "로그인 오류", "애플 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
    } catch (error) {
      logger.e("애플 로그인 오류 - ${error.toString()}");
      customAlert.showTextAlert(
          "로그인 오류", "애플 로그인 오류 입니다.\n잠시후에 다시 시도 해주세요.");
    }
  }

  /// 애플은 성/이름을 나눠서 준다. 한국식 표기(성 + 이름)로 합친다.
  /// 사용자가 이름 제공을 거부했거나 두 번째 로그인이면 null이 되고,
  /// 이 경우 서버는 닉네임 없이 가입시킨다.
  String? _resolveName(AuthorizationCredentialAppleID credential) {
    final family = credential.familyName?.trim() ?? '';
    final given = credential.givenName?.trim() ?? '';
    final name = '$family$given'.trim();
    return name.isEmpty ? null : name;
  }
}
