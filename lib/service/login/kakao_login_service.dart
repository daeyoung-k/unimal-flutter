
import 'dart:io';
import 'dart:convert';

import 'package:kakao_flutter_sdk/kakao_flutter_sdk_talk.dart';
import 'package:http/http.dart' as http;

class KakaoLoginService {
  Future<void> login() async {
    try {
          OAuthToken token = await UserApi.instance.loginWithKakaoAccount();
          var host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
          var url = Uri.http('${host}:8080', 'user/auth/login/mobile/kakao');
          var headers = {"Authorization": "Bearer ${token.accessToken}"};
          var response = await http.get(url, headers: headers);
          var body = jsonDecode(response.body);

          if (body['code'] == 200) {
            print("카카오 로그인 성공");
            print(response.headers);
            print(body);
          } else {
            print("카카오 로그인 실패 ${body['message']}");
          }
        } catch (error) {
          print('카카오톡으로 로그인 실패 $error');
        }
  }
}
